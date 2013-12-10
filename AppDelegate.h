//
//  AppDelegate.h
//  BingDesktop
//
//  Created by abradbury on 20/02/2013.
//  Copyright 2013 abradbury. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSXMLParserDelegate> {
	
	// --------------- The Menu --------------- //
	//NSWindow *window;
	IBOutlet NSMenu	*statusMenu;
	NSStatusItem	*statusItem;
	NSImage			*statusItemImage;
	NSImage			*statusItemImageAlt;
	
	// ------------- The Parsing -------------- //
	NSString		*xmlLocation;		// The URL of the XML file as a String
	NSURL			*xmlUrl;			// The URL of the XML file as a URL
    NSData			*data;				// The data at the URL
	NSMutableData	*responseData;
	NSURLResponse	*urlResponse;
    NSXMLDocument	*document;			// Document that results after parsing the data
	NSString		*imgUrlStr;			// A string of the URL of the image to download
	NSMutableString	*copyrightStr;
	BOOL			foundImgUrl;		// A flag used in parsing the XML for the image URL.
	BOOL			foundCopyright;
	
	// ------------- The Download ------------- //
	NSString		*imgDownloadLoc;	// The location of the downloaded image.
	NSString		*imgDownloadName;	// The name of the downloaded image.
	NSString		*imgPath;			// The path to the downloaded image.
	
	// ------------ The Background ------------ //
    unsigned int options;				// The set of options to use for input from the fidelityMatrix
	
	NSScreen *curScreen;
	
	NSTimer *timer;						// The timer used to schedule checks
}

-(void)saveAppState:(id)sender;
-(void)getAppState:(id)sender;

// --------------- The Menu --------------- //
//@property (assign) IBOutlet NSWindow *window;

// ------------- The Parsing -------------- //
- (void)setData:(NSData *)theData encoding:(NSString *)encoding;
- (void)setDocument:(NSXMLDocument *)doc;
- (void)setURL:(NSURL *)theUrl;

- (IBAction)getXML:(id)sender;

- (BOOL)parseXmlFromURL:(NSURL *)url;

// ------------- The Download ------------- //
- (BOOL)imageExists:(id)sender;
- (void)startDownloadingURL:(id)sender;

// ------------ The Background ------------ //
- (void)setDesktopBackground:(id)sender;

- (void)prepareTimer;

@end
