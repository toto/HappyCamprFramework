//
//  Campfire.h
//  CampfireStreaming
//
//  Created by Randall Brown on 8/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ASIHTTPRequestDelegate.h"
#import "Message.h"
#import "Room.h"
#import "UploadFile.h"
#import "User.h"

@protocol CampfireResponseProtocol

-(void)messageReceived:(Message*)message;

@end

@interface Campfire : NSObject <ASIHTTPRequestDelegate, NSURLConnectionDelegate>
{
   NSString *campfireURL;
   id<CampfireResponseProtocol> delegate;
   NSString *authToken;
}

- (id)initWithCampfireURL:(NSString*)campfireURL;
-(void)startListeningForMessagesInRoom:(NSString*)roomID;
-(void)sendText:(NSString*)messageText toRoom:(NSString*)roomID;
-(void)sendSound:(NSString*)sound toRoom:(NSString*)roomID;
-(void)getMessagesFromRoom:(NSString*)roomID sinceID:(NSInteger)lastMessageID completionHandler:(void (^)(NSArray* messages))handler;

//Rooms
-(void)getVisibleRoomsWithHandler:(void (^)(NSArray* rooms))handler;
-(void)getRoomsAuthenticatedUserIsInWithHandler:(void (^)(NSArray* rooms))handler;
-(void)getRoomWithID:(NSString*)roomID completionHandler:(void (^)(Room *room))handler;
-(void)postFile:(NSString*)file toRoom:(NSString*)roomID completionHandler:(void (^)(UploadFile *file, NSError *error))handler;
-(void)updateRoom:(NSString*)roomID topic:(NSString*)topic name:(NSString*)name completionHandler:(void (^)(NSError *error))handler;
-(void)getRecentlyUploadedFilesFromRoom:(NSString*)roomID completionHandler:(void (^)(NSArray *files, NSError *error))handler;

-(void)joinRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler;
-(void)leaveRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler;
-(void)lockRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler;
-(void)unlockRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler;

//Users
-(void)getUserWithID:(NSString*)userID withCompletionHandler:(void(^)(User *user, NSError*error))handler;
-(void)getAuthenticatedUserInfo:(void(^)(User *user, NSError*error))handler;


@property (assign) id<CampfireResponseProtocol> delegate;
@property (retain) NSString *authToken;

@end
