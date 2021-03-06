//
//  ManageThumbnails.h
//  Owncloud iOs Client
//
//  Created by Gonzalo Gonzalez on 23/12/15.
//

/*
 Copyright (C) 2015, ownCloud, Inc.
 This code is covered by the GNU Public License Version 3.
 For distribution utilizing Apple mechanisms please see https://owncloud.org/contribute/iOS-license-exception/
 You should have received a copy of this license
 along with this program. If not, see <http://www.gnu.org/licenses/gpl-3.0.en.html>.
 */

#import <Foundation/Foundation.h>

@interface ManageThumbnails : NSObject

+ (id) sharedManager;

- (BOOL) isStoredThumbnailWithHash:(NSUInteger) hash;
- (BOOL) storeThumbnail:(NSData *)thumbnail withHash:(NSUInteger) hash;
- (BOOL) removeStoredThumbnailWithHash:(NSUInteger) hash;
- (NSString *) getThumbnailPathForFileHash:(NSUInteger) hash;
- (BOOL) renameStoredThumbnailWithOldHash:(NSUInteger) oldHash withNewHash:(NSUInteger) newHash;
- (void) renameThumbnailOfFile:(FileDto *)oldFile withNewFile:(FileDto *)newFile;
- (void) removeThumbnailIfExistWithFile:(FileDto *)theFile;
- (void) deleteThumbnailsInFolder:(NSInteger)idFile;
- (void) deleteThumbnailCacheFolderOfActiveUser;
- (void) deleteThumbnailCacheFolderOfUserId:(NSInteger) userId ;
@end
