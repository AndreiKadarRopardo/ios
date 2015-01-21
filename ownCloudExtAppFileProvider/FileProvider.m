//
//  FileProvider.m
//  ownCloudExtAppFileProvider
//
//  Created by Gonzalo Gonzalez on 14/10/14.
//

/*
 Copyright (C) 2014, ownCloud, Inc.
 This code is covered by the GNU Public License Version 3.
 For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 You should have received a copy of this license
 along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 */

#import "FileProvider.h"
#import <UIKit/UIKit.h>
#import "ProvidingFileDto.h"
#import "ManageProvidingFilesDB.h"
#import "FMDatabaseQueue.h"
#import "UtilsUrls.h"
#import "ManageFilesDB.h"
#import "FileDto.h"
#import "UploadsOfflineDto.h"
#import "UserDto.h"
#import "ManageUsersDB.h"
#import "constants.h"
#import "ManageUploadsDB.h"


@interface FileProvider ()

@end

@implementation FileProvider

- (NSFileCoordinator *)fileCoordinator {
    NSFileCoordinator *fileCoordinator = [[NSFileCoordinator alloc] init];
    [fileCoordinator setPurposeIdentifier:[self providerIdentifier]];
    return fileCoordinator;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self.fileCoordinator coordinateWritingItemAtURL:[self documentStorageURL] options:0 error:nil byAccessor:^(NSURL *newURL) {
            // ensure the documentStorageURL actually exists
            NSError *error = nil;
            [[NSFileManager defaultManager] createDirectoryAtURL:newURL withIntermediateDirectories:YES attributes:nil error:&error];
        }];
    }
    return self;
}

- (void)providePlaceholderAtURL:(NSURL *)url completionHandler:(void (^)(NSError *error))completionHandler {
    // Should call + writePlaceholderAtURL:withMetadata:error: with the placeholder URL, then call the completion handler with the error if applicable.
    NSString* fileName = [url lastPathComponent];
    
    NSURL *placeholderURL = [NSFileProviderExtension placeholderURLForURL:[self.documentStorageURL URLByAppendingPathComponent:fileName]];
    
    NSUInteger fileSize = 0;
    // TODO: get file size for file at <url> from model
    
    [self.fileCoordinator coordinateWritingItemAtURL:placeholderURL options:0 error:NULL byAccessor:^(NSURL *newURL) {
        
        NSDictionary* metadata = @{ NSURLFileSizeKey : @(fileSize)};
        [NSFileProviderExtension writePlaceholderAtURL:placeholderURL withMetadata:metadata error:NULL];
    }];
    if (completionHandler) {
        completionHandler(nil);
    }
}

- (void)startProvidingItemAtURL:(NSURL *)url completionHandler:(void (^)(NSError *))completionHandler {
    // Should ensure that the actual file is in the position returned by URLForItemWithIdentifier:, then call the completion handler
    NSError* error = nil;
   
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path])
    {
        error = [NSError errorWithDomain:NSPOSIXErrorDomain code:-1 userInfo:nil];
    }
    
    NSLog(@"Provider identifier : %@", self.description);
    
    if (completionHandler) {
        completionHandler(error);
    }
}


- (void)itemChangedAtURL:(NSURL *)url {
    // Called at some point after the file has changed; the provider may then trigger an upload
    
    // TODO: mark file at <url> as needing an update in the model; kick off update process
    NSLog(@"Item changed at URL %@", url);

    //TODO: Here we have to init the upload of the file

    for (ProvidingFileDto *pFile in [ManageProvidingFilesDB getAllProvidingFilesDto]) {
        DLog(@"pfile path: %@", pFile.filePath);
    }
    
    NSString *path = [url.path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    ProvidingFileDto *providingFile = [ManageProvidingFilesDB getProvidingFileDtoByPath:[UtilsUrls getRelativePathForDocumentProviderUsingAboslutePath:path]];
    
    
    if (providingFile) {
        FileDto *file = [ManageFilesDB getFileDtoRelatedWithProvidingFileId:providingFile.idProvidingFile ofUser:providingFile.userId];
        
        NSLog(@"File name %@", file.fileName);
        
        [self moveFileOnTheFileSystemByOrigin:url.path andDestiny:file.localFolder];
        
        [self createUploadOfflineWithFile:file fromPath:url.path withUser:file.userId];
        
        [self removeItemByUrl:url];
        
    }


    //Move file to a filesystem
    
    //Create the offline upload

}

- (void)stopProvidingItemAtURL:(NSURL *)url {
    // Called after the last claim to the file has been released. At this point, it is safe for the file provider to remove the content file.
    // Care should be taken that the corresponding placeholder file stays behind after the content file has been deleted.
    
    [self removeItemByUrl:url];
    
    [self.fileCoordinator coordinateWritingItemAtURL:url options:NSFileCoordinatorWritingForDeleting error:NULL byAccessor:^(NSURL *newURL) {
        [[NSFileManager defaultManager] removeItemAtURL:newURL error:NULL];
    }];
    [self providePlaceholderAtURL:url completionHandler:NULL];
}

- (void) removeItemByUrl:(NSURL *)url {
    
    NSArray *all = [ManageProvidingFilesDB getAllProvidingFilesDto];
    
    DLog(@"Path: %@", url.path);
    
    ProvidingFileDto *providingFile = [ManageProvidingFilesDB getProvidingFileDtoByPath:url.path];
    
    if (providingFile) {
        FileDto *file = [ManageFilesDB getFileDtoRelatedWithProvidingFileId:providingFile.idProvidingFile ofUser:providingFile.userId];
        
        NSLog(@"File name %@", file.fileName);
        
        //For test, delete the ProvidingFile
        [ManageProvidingFilesDB removeProvidingFileDtoById:providingFile.idProvidingFile];
        [ManageFilesDB updateFile:file.idFile withProvidingFile:0];
    }
    
}


-(void) moveFileOnTheFileSystemByOrigin:(NSString *) origin andDestiny:(NSString *) destiny {
    
    DLog(@"origin: %@",origin);
    DLog(@"destiny: %@", destiny);
    
    NSFileManager *filemgr;
    
    filemgr = [NSFileManager defaultManager];
    
    [filemgr removeItemAtPath:destiny error:nil];
    
    NSURL *oldPath = [NSURL fileURLWithPath:origin];
    NSURL *newPath= [NSURL fileURLWithPath:destiny];
    
    [filemgr moveItemAtURL: oldPath toURL: newPath error: nil];
}


- (void) createUploadOfflineWithFile:(FileDto *) file fromPath:(NSString *)path withUser:(NSInteger)userId {
    
    UserDto *user = [ManageUsersDB getUserByIdUser:userId];
    
    NSString *remotePath = [NSString stringWithFormat: @"%@%@%@%@", user.url, k_url_webdav_server, file.filePath, file.fileName];
    
    long long fileLength = [[[[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil] valueForKey:NSFileSize] unsignedLongLongValue];
    
    UploadsOfflineDto *upload = [UploadsOfflineDto new];
    

    upload.originPath = file.localFolder;
    upload.destinyFolder = remotePath;
    upload.uploadFileName = file.fileName;
    upload.kindOfError = notAnError;
    
    upload.estimateLength = (long)fileLength;
    upload.userId = userId;
    upload.isLastUploadFileOfThisArray = YES;
    upload.status = pendingToBeCheck;
    upload.chunksLength = k_lenght_chunk;
    upload.isNotNecessaryCheckIfExist = YES;
    upload.isInternalUpload = NO;
    upload.taskIdentifier = 0;
    
    [ManageUploadsDB insertUpload:upload];
    
}

#pragma mark - FMDataBase
+ (FMDatabaseQueue*)sharedDatabase
{
    
    BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[[UtilsUrls getOwnCloudFilePath] stringByAppendingPathComponent:@"DB.sqlite"]];
    
    static FMDatabaseQueue* sharedDatabase = nil;
    if (sharedDatabase == nil)
    {
        NSString *documentsDir = [UtilsUrls getOwnCloudFilePath];
        NSString *dbPath = [documentsDir stringByAppendingPathComponent:@"DB.sqlite"];
        
        
        //NSString* bundledDatabasePath = [[NSBundle mainBundle] pathForResource:@"DB" ofType:@"sqlite"];
        sharedDatabase = [[FMDatabaseQueue alloc] initWithPath: dbPath];
    }
    
    return sharedDatabase;
}

@end
