HappyCampfire is an objective-c wrapper around most of the Campfire API. It has model objects like users, messages, and rooms. It should allow anyone familiar with Cocoa programming to get right to work on making an app. It is designed to work on both OS X and iOS but most of the work/testing has been on OS X.

I wanted to put this out there to help people make good innovative uses of Campfire, without having to deal with too many of the nitty gritty details. It's definitely still a bit of a work in progress so feel free to fork it and send me a pull request if want to fix/add anything.

The framework is designed to be asynchronous and uses ASIHTTPRequest for the network communication. It also allows you to make use of Campfire's streaming API to get message updates. The project includes a test app for OS X that will let you test all of the different parts of the framework.

To get started you'll create an object like this

```
HappyCampfire campfire = [[HappyCampfire alloc] initWithCampfireURL:@"https://yourCampfireURL.campfirenow.com"];
campfire.delegate = self; // for using the streaming api
campfire.authToken = @"YOUR_AUTH_TOKEN";
```
You can also authenticate using the campfire object.

```   
[campfire authenticateUserWithName:[username stringValue] password:[password stringValue] 
                                                 completionHandler:^(HCUser* user, NSError *error){
      NSLog(@"%@",user.authToken);
   }];
```
Authenticating this way will store the authToken inside the HappyCampfire object so you won't have to set it yourself.

Sending a message is simple

```
[campfire sendText:@"Hello World" toRoom:@"ROOM_ID" 
                       completionHandler:^(HCMessage *message, NSError *error){
      NSLog(@"%@", message);
   }];
```

Everything else uses blocks to get call backs. All of the blocks will be called on the main thread.