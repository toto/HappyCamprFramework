//
//  Campfire.m
//  CampfireStreaming
//
//  Created by Randall Brown on 8/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Campfire.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "SBJSON.h"
#import "Room.h"
#import "User.h"

@interface Campfire() 

-(User*)userWithUserElement:(NSXMLElement*)element;

@end

@implementation Campfire
@synthesize delegate;
@synthesize authToken;

- (id)initWithCampfireURL:(NSString*)aCampfireURL
{
    self = [super init];
    if (self) {
       campfireURL = [aCampfireURL retain];
    }
    
    return self;
}

-(void)dealloc
{
   [campfireURL release];
}

-(NSString*)messageWithType:(NSString*)messageType andMessage:(NSString*)message
{
   return [NSString stringWithFormat:@"<message><type>%@</type><body>%@</body></message>", messageType, message];
}

-(void)startListeningForMessagesInRoom:(NSString*)roomID
{
   NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"https://streaming.campfirenow.com/room/%@/live.json",  roomID]];
   ASIHTTPRequest *streamRequest = [[ASIHTTPRequest alloc] initWithURL:url];
   streamRequest.delegate = self;
   [streamRequest setAuthenticationScheme:(NSString *)kCFHTTPAuthenticationSchemeBasic];
   [streamRequest setUsername:authToken];
   [streamRequest setPassword:@"X"];
   [streamRequest setShouldAttemptPersistentConnection:YES];
   
   [streamRequest startAsynchronous];   
}


-(void)request:(ASIHTTPRequest *)request didReceiveData:(NSData *)data
{
   NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
   
   if( !([data length] > 1) )
      return;
   
   NSArray *messagesInStrings = [dataString componentsSeparatedByString:@"}"];
   NSMutableArray *fixedMessageStrings = [NSMutableArray array];
   int i=0;
   for( NSString *messageString in  messagesInStrings )
   {
      [fixedMessageStrings addObject:[messageString stringByAppendingString:@"}"]];
      i++;
   }
   
   for( NSString *fixedString in fixedMessageStrings )
   {
      SBJsonParser *jsonParser = [[[SBJsonParser alloc] init] autorelease];
      
      if( !([fixedString length] > 2) )
         continue;
      
      id messageDict = [jsonParser objectWithString:fixedString];
      Message *message = [[[Message alloc] init] autorelease];
      
      message.messageBody = [messageDict objectForKey:@"body"];
      
      
      message.timeStamp = [NSDate dateWithString:[messageDict objectForKey:@"created_at"]];
      message.messageId = [[messageDict objectForKey:@"id"] intValue];
      message.messageType = [messageDict objectForKey:@"type"];
      message.userID = [[messageDict objectForKey:@"user_id"] intValue];
      [delegate messageReceived:message];      
   }
   
}

-(void)requestFailed:(ASIHTTPRequest *)request
{
   NSLog(@"Request Failed %@",[request error]);
   [delegate listeningFailed:[request error]];
}

-(void)requestFinished:(ASIHTTPRequest *)request
{
   NSLog(@"Request Finished");
   NSLog(@"%@", request);
}

-(void)sendText:(NSString*)messageText toRoom:(NSString*)roomID
{   
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/speak.xml",campfireURL,roomID];
   
   __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
   
   [request addRequestHeader:@"Content-Type" value:@"application/xml"];
   [request setAuthenticationScheme:(NSString *)kCFHTTPAuthenticationSchemeBasic];
   [request setUsername:authToken];
   [request setPassword:@"X"];
   
   NSString *postBody = [self messageWithType:@"TextMessage" andMessage:messageText];
   
   [request setPostBody:[postBody dataUsingEncoding:NSUTF8StringEncoding]];
   
   [request setCompletionBlock:^{
      //  NSLog(@"%@", [request responseString]);
   }];
   
   [request startAsynchronous];   
}

-(ASIHTTPRequest*)requestWithURL:(NSURL*)url
{
   ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
   
   [request addRequestHeader:@"Content-Type" value:@"application/xml"];
   [request setAuthenticationScheme:(NSString *)kCFHTTPAuthenticationSchemeBasic];
   [request setUsername:authToken];
   [request setPassword:@"X"];   
   
   return request;
}

-(void)getMessagesFromRoom:(NSString*)roomID sinceID:(NSInteger)lastMessageID completionHandler:(void (^)(NSArray* messages))handler
{
   
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/recent.xml?since_message_id=%i",campfireURL ,roomID, lastMessageID];
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   
   [request setCompletionBlock:^{
      NSMutableArray *messages = [NSMutableArray array];
      
      NSString *responseString = [request responseString];
      
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:responseString options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      NSArray *messageElements = [[responseDoc rootElement] elementsForName:@"message"];

      for( NSXMLElement *messageElement in messageElements )
      {
         Message *message = [[Message new] autorelease];
         
         message.messageId = [[[[messageElement elementsForName:@"id"] lastObject] stringValue] intValue];
         
         NSDateFormatter *dateFormatter = [[NSDateFormatter new] autorelease];
         [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
         [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
         message.timeStamp = [dateFormatter dateFromString:[[[messageElement elementsForName:@"created-at"] lastObject] stringValue]];
         message.roomID = [[[[messageElement elementsForName:@"room-id"] lastObject] stringValue] intValue];
         message.userID = [[[[messageElement elementsForName:@"user-id"] lastObject] stringValue] intValue];
         message.messageBody = [[[messageElement elementsForName:@"body"] lastObject] stringValue];
         message.messageType = [[[messageElement elementsForName:@"type"] lastObject] stringValue];

         [messages addObject:message];
      }
      handler( messages );
   }];
   
   [request startAsynchronous];    
}

-(void)getVisibleRoomsWithHandler:(void (^)(NSArray* rooms))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/rooms.xml",campfireURL];
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   [request setCompletionBlock:^{
      NSString *responseString = [request responseString];

      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:responseString options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      NSArray *roomElements = [[responseDoc rootElement] elementsForName:@"room"];
      NSMutableArray *rooms = [NSMutableArray array];
      for( NSXMLElement *roomElement in roomElements )
      {
         Room *room = [[Room new] autorelease];
         
         room.roomID = [[[roomElement elementsForName:@"id"] lastObject] stringValue];
         room.name = [[[roomElement elementsForName:@"name"] lastObject] stringValue];
         room.topic = [[[roomElement elementsForName:@"topic"] lastObject] stringValue];
         
         [rooms addObject:room];
      }
      
      handler( rooms );
   }];
   
   [request startAsynchronous];
}

-(void)getRoomsAuthenticatedUserIsInWithHandler:(void (^)(NSArray* rooms))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/presence.xml",campfireURL];
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   [request setCompletionBlock:^{
      NSString *responseString = [request responseString];
      
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:responseString options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      NSArray *roomElements = [[responseDoc rootElement] elementsForName:@"room"];
      NSMutableArray *rooms = [NSMutableArray array];
      for( NSXMLElement *roomElement in roomElements )
      {
         Room *room = [[Room new] autorelease];
         
         room.roomID = [[[roomElement elementsForName:@"id"] lastObject] stringValue];
         room.name = [[[roomElement elementsForName:@"name"] lastObject] stringValue];
         room.topic = [[[roomElement elementsForName:@"topic"] lastObject] stringValue];
         
         [rooms addObject:room];
      }
      
      handler( rooms );
   }];
   
   [request startAsynchronous];   
}

-(void)getRoomWithID:(NSString*)roomID completionHandler:(void (^)(Room *room))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@.xml", campfireURL, roomID];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   
   [request setCompletionBlock:^{
      NSString *responseString = [request responseString];
      
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:responseString options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      Room *room = [[Room new] autorelease];
      NSXMLElement *roomElement = [responseDoc rootElement];
      
      room.roomID = [[[roomElement elementsForName:@"id"] lastObject] stringValue];
      room.name = [[[roomElement elementsForName:@"name"] lastObject] stringValue];
      room.topic = [[[roomElement elementsForName:@"topic"] lastObject] stringValue];
      
      NSArray *userElements = [[[[responseDoc rootElement] elementsForName:@"users"] lastObject] elementsForName:@"user"];
      NSMutableArray *usersInRoom = [NSMutableArray array];
      
      for( NSXMLElement *userElement in userElements )
      {
         User *user = [self userWithUserElement:userElement];
         
         [usersInRoom addObject:user];
      }
      
      room.users = usersInRoom;
      
      
      handler( room );
      
   }];
   
   [request startAsynchronous];    
}

-(UploadFile *)uploadFileWithUploadElement:(NSXMLElement*)element
{
   UploadFile *file = [[UploadFile new] autorelease];
   file.sizeInBytes = [[[[element elementsForName:@"byte-size"] lastObject] stringValue] intValue];
   file.fullURL = [[[element elementsForName:@"full-url"] lastObject] stringValue];
   file.contentType = [[[element elementsForName:@"content-type"] lastObject] stringValue];
   
   NSDateFormatter *dateFormatter = [[NSDateFormatter new] autorelease];
   [dateFormatter setTimeZone:[NSTimeZone localTimeZone]];
   [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss'Z'"];
   file.createdAt = [dateFormatter dateFromString:[[[element elementsForName:@"created-at"] lastObject] stringValue]];
   file.fileID = [[[[element elementsForName:@"id"] lastObject] stringValue] intValue];
   file.name = [[[element elementsForName:@"name"] lastObject] stringValue];
   file.roomID = [[[element elementsForName:@"room-id"] lastObject] stringValue];
   file.userID = [[[element elementsForName:@"user-id"] lastObject] stringValue]; 
   return file;
}

-(void)postFile:(NSString*)file toRoom:(NSString*)roomID completionHandler:(void (^)(UploadFile *file, NSError *error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/uploads.xml", campfireURL, roomID];
   
   __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:urlString]];
   [request addRequestHeader:@"Content-Type" value:@"multipart/form-data"];
   [request setAuthenticationScheme:(NSString *)kCFHTTPAuthenticationSchemeBasic];
   [request setUsername:authToken];
   [request setPassword:@"X"];
   
   [request setFile:file forKey:@"upload"];
   
   [request setCompletionBlock:^{
      
      
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:[request responseString] options:NSXMLDocumentTidyXML error:nil] autorelease];

      UploadFile *file = [self uploadFileWithUploadElement:[responseDoc rootElement]];
      
      handler(file,[request error]);
   }];
    
   [request setFailedBlock:^{
      handler(nil,[request error]);
   }];
   
   [request startAsynchronous];
}

-(void)updateRoom:(NSString*)roomID topic:(NSString*)topic name:(NSString*)name completionHandler:(void (^)(NSError *error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@.xml", campfireURL, roomID];
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   
   NSString *postString = [NSString stringWithFormat:@"<room><name>%@</name><topic>%@</topic></room>", name, topic];
   

   [request setPostBody:[postString dataUsingEncoding:NSUTF8StringEncoding]];
      [request setRequestMethod:@"PUT"];
   [request startAsynchronous];
   
}

-(void)getRecentlyUploadedFilesFromRoom:(NSString*)roomID completionHandler:(void (^)(NSArray *files, NSError *error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/uploads.xml", campfireURL, roomID];
   
   __block ASIFormDataRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];

   
   [request setCompletionBlock:^{
      
      
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:[request responseString] options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      NSArray *uploadFileElements = [[responseDoc rootElement] elementsForName:@"upload"];
      NSMutableArray *uploadFiles = [NSMutableArray array];
      for( NSXMLElement *uploadFileElement in uploadFileElements )
      {
         
         UploadFile *file = [self uploadFileWithUploadElement:uploadFileElement];
         [uploadFiles addObject:file];
      }
      
      handler(uploadFiles,[request error]);
   }];
   
   [request setFailedBlock:^{
      handler(nil,[request error]);
   }];
   
   [request startAsynchronous];   
}

-(void)joinRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/join.xml", campfireURL, roomID];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   [request setRequestMethod:@"POST"];

   
   [request setCompletionBlock:^{
      handler( [request error] );
      
   }];
   
   [request startAsynchronous];   
}

-(void)leaveRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/leave.xml", campfireURL, roomID];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   [request setRequestMethod:@"POST"];
   
   
   [request setCompletionBlock:^{
      handler( [request error] );
      
   }];
   
   [request startAsynchronous];     
}

-(void)lockRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/lock.xml", campfireURL, roomID];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   [request setRequestMethod:@"POST"];
   
   
   [request setCompletionBlock:^{
      handler( [request error] );
      
   }];
   
   [request startAsynchronous];     
}

-(void)unlockRoom:(NSString*)roomID WithCompletionHandler:(void (^)(NSError *error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/unlock.xml", campfireURL, roomID];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   [request setRequestMethod:@"POST"];
   
   
   [request setCompletionBlock:^{
      handler( [request error] );
      
   }];
   
   [request startAsynchronous];     
}

-(User*)userWithUserElement:(NSXMLElement*)element
{
   User *user = [[User new] autorelease];
   
   user.userID = [[[[element elementsForName:@"id"] lastObject] stringValue] intValue];
   user.name = [[[element elementsForName:@"name"] lastObject] stringValue];
   user.email = [[[element elementsForName:@"email-address"] lastObject] stringValue];
   user.avatarURL = [[[element elementsForName:@"avatar-url"] lastObject] stringValue];
   user.authToken = [[[element elementsForName:@"api-auth-token"] lastObject] stringValue];
   
   return user;
}

-(void)getUserWithID:(NSString*)userID withCompletionHandler:(void(^)(User*user, NSError*error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/users/%@.xml", campfireURL, userID];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   
   [request setCompletionBlock:^{
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:[request responseString] options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      NSXMLElement *userElement = [responseDoc rootElement];
      User *user = [self userWithUserElement:userElement];
      handler( user, [request error] );
      
   }];
   
   [request startAsynchronous];     
}

-(void)getAuthenticatedUserInfo:(void(^)(User *user, NSError*error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/users/me.xml", campfireURL];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   
   [request setCompletionBlock:^{
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:[request responseString] options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      NSXMLElement *userElement = [responseDoc rootElement];
      User *user = [self userWithUserElement:userElement];
      handler( user, [request error] );
      
   }];
   
   [request startAsynchronous];     
}

-(void)authenticateUserWithName:(NSString*)userName password:(NSString*)password completionHandler:(void(^)(User *user, NSError*error))handler
{
   NSString *urlString = [NSString stringWithFormat:@"%@/users/me.xml", campfireURL];
   
   __block ASIHTTPRequest *request = [self requestWithURL:[NSURL URLWithString:urlString]];
   [request setUsername:userName];
   [request setPassword:password];
   
   [request setCompletionBlock:^{
      NSXMLDocument *responseDoc = [[[NSXMLDocument alloc] initWithXMLString:[request responseString] options:NSXMLDocumentTidyXML error:nil] autorelease];
      
      NSXMLElement *userElement = [responseDoc rootElement];
      User *user = [self userWithUserElement:userElement];
      handler( user, [request error] );
      authToken = user.authToken;
      
   }];
   
   [request startAsynchronous];     
}

-(void)sendSound:(NSString*)sound toRoom:(NSString*)roomID
{
   NSString *urlString = [NSString stringWithFormat:@"%@/room/%@/speak.xml",campfireURL,roomID];
   
   
   __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:urlString]];
   
   [request addRequestHeader:@"Content-Type" value:@"application/xml"];
   [request setAuthenticationScheme:(NSString *)kCFHTTPAuthenticationSchemeBasic];
   [request setUsername:authToken];
   [request setPassword:@"X"];
   
   NSString *postBody = [self messageWithType:@"SoundMessage" andMessage:sound];
   
   [request setPostBody:[postBody dataUsingEncoding:NSUTF8StringEncoding]];
   
   [request setCompletionBlock:^{
      //  NSLog(@"%@", [request responseString]);
   }];
   
   [request startAsynchronous];      
}

@end
