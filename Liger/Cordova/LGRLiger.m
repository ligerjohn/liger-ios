//
//  LGRLiger.m
//  Liger
//
//  Created by John Gustafsson on 2/25/13.
//  Copyright (c) 2013-2014 ReachLocal Inc. All rights reserved.  https://github.com/reachlocal/liger-ios/blob/master/LICENSE
//

#import "LGRLiger.h"
#import "LGRViewController.h"
#import "LGRSlideViewController.h"

#import "LGRCordovaViewController.h"

@interface LGRBlock : NSObject {
	void (^_block)();
}
- (id)initWithBlock:(void (^)())block;
- (void)invoke;
@end

@implementation LGRBlock

- (id)initWithBlock:(void (^)())block
{
	self = [super init];
	if (self) {
		_block = block;
	}
	return self;
}

- (void)invoke
{
	_block();
}

@end

NSString* checkString(NSString* string)
{
	NSCAssert([string isKindOfClass:NSString.class], @"Make sure you send a string and not a null as a parameter.");
	return [string isKindOfClass:NSString.class] ? string : @"";
}

NSDictionary* checkDictionary(id dictionary)
{
	NSCAssert([dictionary isKindOfClass:NSDictionary.class] || [dictionary isKindOfClass:NSNull.class], @"Arguments (args) should be dictionaries.");
	return [dictionary isKindOfClass:NSDictionary.class] ? dictionary : @{};
}

@interface LGRLiger ()
@property (readonly) UINavigationController *navigationController;
@property (readonly) LGRViewController* ligerViewController;
@property (nonatomic, strong) NSMutableArray *toolbarCallbacks;
@end

@implementation LGRLiger

#pragma mark - Page

- (void)openPage:(CDVInvokedUrlCommand*)command
{
	if (command.arguments.count < 2) {
		[self sendERROR:command.callbackId];
		return;
	}

	NSString *title = checkString(command.arguments[0]);
	NSString *page = checkString(command.arguments[1]);
	NSDictionary *args = checkDictionary(command.arguments.count > 2 ? command.arguments[2] : @{});
	
	[self.ligerViewController openPage:page title:title args:args success:^{
		[self sendOK:command.callbackId];
	} fail:^{
		[self sendERROR:command.callbackId];
	}];
}

- (void)closePage:(CDVInvokedUrlCommand*)command
{
	if (command.arguments.count > 1) {
		[self sendERROR:command.callbackId];
		return;
	}

	NSString *rewindTo = nil;
	
	if (command.arguments.count == 1) {
		rewindTo = checkString(command.arguments[0]);
	}
	
	[self.ligerViewController closePage:rewindTo success:^{
		[self sendOK:command.callbackId];
	} fail:^{
		[self sendERROR:command.callbackId];
	}];
}

- (void)updateParent:(CDVInvokedUrlCommand*)command
{
	if (command.arguments.count != 2) {
		[self sendERROR:command.callbackId];
		return;
	}
	
	NSString *destination = command.arguments[0];
	NSDictionary *args = checkDictionary(command.arguments[1]);

	[self.ligerViewController updateParent:destination args:args success:^{
		[self sendOK:command.callbackId];
	} fail:^{
		[self sendERROR:command.callbackId];
	}];
}

- (void)getPageArgs:(CDVInvokedUrlCommand*)command
{
	NSDictionary *args = self.ligerViewController.args;
	if (!args)
		args = @{};

	[self sendOK:command.callbackId messageAsDictionary:args];
}

#pragma mark - Dialog

- (void)openDialog:(CDVInvokedUrlCommand*)command
{
	if (!command.arguments.count) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
		return;
	}
	
	NSString *page = checkString(command.arguments[0]);
	NSDictionary *args = checkDictionary(command.arguments.count > 1 ? command.arguments[1] : @{});
	
	[self.ligerViewController openDialog:page title:nil args:args success:^{
		[self sendOK:command.callbackId];
	} fail:^{
		[self sendERROR:command.callbackId];
	}];
}

- (void)openDialogWithTitle:(CDVInvokedUrlCommand*)command
{
	if (command.arguments.count < 3) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
		return;
	}

	NSString *title = checkString(command.arguments[0]);
	NSString *page = checkString(command.arguments[1]);
	NSDictionary *args = checkDictionary(command.arguments.count > 2 ? command.arguments[2] : @{});

	[self.ligerViewController openDialog:page title:title args:args success:^{
		[self sendOK:command.callbackId];
	} fail:^{
		[self sendERROR:command.callbackId];
	}];
}

- (void)closeDialog:(CDVInvokedUrlCommand*)command
{
	if (command.arguments.count != 1) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
		return;
	}

	NSDictionary *args = checkDictionary(command.arguments[0]);
	
	[self.ligerViewController closeDialog:args success:^{
		[self sendOK:command.callbackId];
	} fail:^{
		[self sendERROR:command.callbackId];
	}];
}

#pragma mark - Toolbar

- (void)toolbar:(CDVInvokedUrlCommand*)command
{
	if (command.arguments.count < 1) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
		return;
	}

	NSArray *items = command.arguments[0];
	if ([items isKindOfClass:NSNull.class] || !items.count) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
		return;
	}

	self.ligerViewController.toolbarItems = [self buildToolbar:items];
	
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (NSMutableArray*)toolbarCallbacks
{
	if (!_toolbarCallbacks) {
		_toolbarCallbacks = [NSMutableArray arrayWithCapacity:5];
	}
	return _toolbarCallbacks;
}

- (NSArray*)buildToolbar:(NSArray*)items
{
	NSMutableArray *toolbarItems = [NSMutableArray arrayWithCapacity:items.count];
	
	for (NSDictionary *item in items) {
		if (!toolbarItems.count) {
			[toolbarItems addObject:[[UIBarButtonItem  alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
		}

		UIWebView *web = self.webView;
		
		LGRBlock *block = [[LGRBlock alloc] initWithBlock:^{
			[web stringByEvaluatingJavaScriptFromString:item[@"callback"]];
		}];
		[self.toolbarCallbacks addObject:block];
		
		UIBarButtonItem *button = [[UIBarButtonItem  alloc] initWithTitle:item[@"iconText"]
																	style:UIBarButtonItemStylePlain
																   target:block
																   action:@selector(invoke)];
		
		[toolbarItems addObject:button];
		[toolbarItems addObject:[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil]];
	}
	return toolbarItems;
}

#pragma mark - Refresh

- (void)userCanRefresh:(CDVInvokedUrlCommand*)command
{
	if (command.arguments.count != 1) {
		CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
		[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
		return;
	}

	BOOL userCanRefresh = [command.arguments[0] boolValue];
	
	self.ligerViewController.userCanRefresh = userCanRefresh;

	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

#pragma mark - helper methods

- (LGRViewController*)ligerViewController
{
	NSAssert([self.viewController.parentViewController isKindOfClass:LGRViewController.class], @"Internal Liger cordova plugin error");
	return (LGRViewController*)self.viewController.parentViewController;
}

- (void)sendOK:(NSString*)callbackId
{
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

- (void)sendOK:(NSString*)callbackId messageAsDictionary:(NSDictionary *)message
{
	CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:message];
	[self.commandDelegate sendPluginResult:pluginResult
								callbackId:callbackId];
}

- (void)sendERROR:(NSString*)callbackId
{
	CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
	[self.commandDelegate sendPluginResult:pluginResult callbackId:callbackId];
}

@end
