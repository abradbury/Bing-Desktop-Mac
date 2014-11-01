//
//  AppDelegate.m
//  BingDesktop
//
//  Created by abradbury on 20/02/2013.
//  Copyright 2013 abradbury. All rights reserved.
//
// TODO: Add a random menu item that randomly selects one of the other Bing desktop items if the user is not happy with the current one.
//

#import "AppDelegate.h"


@implementation AppDelegate

/*
 *	Initial application configuration.
 */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	xmlLocation = @"http://www.bing.com/hpimagearchive.aspx?format=xml&idx=0&n=1&mbl=0&mkt=en-ww";
	copyrightStr = [[NSMutableString alloc] init];
	imgDownloadLoc = @"~/Pictures/Bing Desktop/";
	imgDownloadName = @"bingImage.jpg";
	imgPath = [[imgDownloadLoc stringByExpandingTildeInPath] stringByAppendingPathComponent:imgDownloadName];
	
	[self getAppState:nil];	// Gets the previous image details
	[self getXML:nil];		// On startup, check for new image
	
	//[self prepareTimer];
}

- (void)dealloc {
	[statusItemImage release];
	[statusItemImageAlt release];
	[super dealloc];
}


-(void)saveAppState:(id)sender {
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *imageCopyright = copyrightStr; 
	NSImage *backgroundImage = [[NSImage alloc] initByReferencingFile:imgPath];
	NSData *imageData = [backgroundImage TIFFRepresentation];
	
	// Store the data
	[defaults setObject:imageCopyright forKey:@"copyright"];
	NSLog(@"Copyright string saved.");
	[defaults setObject:imageData forKey:@"image"];
	NSLog(@"Image data saved.");
	[defaults synchronize];
	
	//NSLog(@"Image path: %@", imgPath);
	
	NSLog(@"Data saved");
}

/*
 *	Gets the previous state of the application, such as the copyright string 
 *	and background image.
 */
-(void)getAppState:(id)sender {
	NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
	
	NSString *savedCopyright = [defaults objectForKey:@"copyright"];
	if (savedCopyright) {
		[copyrightStr setString:savedCopyright];
		[statusItem setToolTip:copyrightStr];
		NSLog(@"Previous copyright string found.");
	} else {
		NSLog(@"No previous copyright string found.");
	}
	
	/*
	 * Is there much point in this at the moment? Surely storing the path
	 * to the image would be better than storing the actual image?
	 */
	NSData *imageData = [defaults dataForKey:@"image"];
	if (imageData) {
		//NSImage *backgroundImage = [[NSImage alloc] initWithData:imageData];
		NSLog(@"Previous image data found.");
		//NSLog(@"%@", imageData);
		//NSLog(@"Image path: %@", imgPath);
	} else {
		NSLog(@"No previous image data found.");
	}
}

-(void)prepareTimer{
	//NSDate date = nil;
	//NSTimer timer = nil;
	
	NSLog(@"Timer set up");
	
	// 86400 = 24 hours
	timer = [[NSTimer alloc] initWithFireDate:[NSDate date] interval:15 target:self selector:@selector(onTimerFire:) userInfo:nil repeats:YES];
	[[NSRunLoop mainRunLoop] addTimer: timer forMode:NSDefaultRunLoopMode];
}

-(void)onTimerFire: (NSTimer *) inTimer {
	NSLog(@"timer: <%@>", inTimer);
	
	// Reset timer
	//if (timer) {
	//	[timer invalidate];
	//	[timer release];
	//	timer = nil;
	//}
}

// --------------- The Menu --------------- //

/*
 *	Creates the menu.
 */
-(void)awakeFromNib{
	// Create the NSStatusItem, add the statusMenus to it and enable highlighting
	statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
	[statusItem setMenu:statusMenu];
	[statusItem setHighlightMode:YES];

	// Define the main image for the statusItem
	statusItemImage = [NSImage imageNamed:@"b-black"];
	if( !statusItemImage ) {
		NSLog(@"ERROR: Could not load the image for 'b-black.png'");
	} else {
		[statusItem setImage:statusItemImage];
	}

	// Define the image to use when the statusItem is highlighted
	statusItemImageAlt = [NSImage imageNamed:@"b-white"];
	if( !statusItemImageAlt ) {
		NSLog(@"ERROR: Could not load the image for 'b-white.png'");
	} else {
		[statusItem setAlternateImage:statusItemImageAlt];
	}
}

// ------------- The Parsing -------------- //

- (IBAction)getXML:(id)sender {
	[self setURL:[NSURL URLWithString:xmlLocation]]; 
	
	[copyrightStr setString:@""];
	
	// Asynchronously get the data
	NSURLRequest *request = [NSURLRequest requestWithURL:xmlUrl];
	[[NSURLConnection alloc]initWithRequest:request delegate:self]; //release later
}


-(void)connection:(NSURLConnection*)connection didReceiveResponse:(NSURLResponse*)response {
    responseData = [[NSMutableData alloc] init];
	urlResponse = [response retain];
}

-(void)connection:(NSURLConnection*)connection didReceiveData:(NSData*)dataReceived {
    [responseData appendData:dataReceived];
}

-(void)connection:(NSURLConnection*)connection didFailWithError:(NSError*)error {
	[responseData release];
	[connection release];
	NSLog(@"Unable to fetch XML data.");
}

-(void)connectionDidFinishLoading:(NSURLConnection*)connection {
	NSLog(@"Successfully received %lu bytes of data for XML file.", (unsigned long)[responseData length]);
		
	[self setData:responseData encoding:[urlResponse textEncodingName]];
	if (!responseData) {
		NSLog(@"Error getting XML.");
		[self setDocument:nil]; // clear out old value
	}
	[self parseXmlFromURL:nil];
}


-(BOOL)parseXmlFromURL:(id)sender {
	if (xmlUrl == NO)
		return NO;
		
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithContentsOfURL:xmlUrl];
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:NO];
	
	BOOL ok = [xmlParser parse];
	if (ok == NO)
		NSLog(@"Error parsing XML.");
	else
		NSLog(@"XML parsed successfully.");
		
	[NSXMLParser release];
	return ok;
}

-(void)parserDidStartDocument:(NSXMLParser *)parser {
	NSLog(@"Started parsing XML...");
}

-(void)parserDidEndDocument:(NSXMLParser *)parser {
	NSLog(@"Found image copyright: %@", copyrightStr);
	NSLog(@"Finished parsing XML.");
	[statusItem setToolTip:copyrightStr];
	[self imageExists:nil];
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if([elementName isEqualToString:@"urlBase"])
		foundImgUrl = YES;
	else if([elementName isEqualToString:@"copyright"])
		foundCopyright = YES;
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if([elementName isEqualToString:@"urlBase"])
		foundImgUrl = NO;
	else if([elementName isEqualToString:@"copyright"])
		foundCopyright = NO;
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)value {
	if(foundImgUrl == YES) {
		imgUrlStr = [NSString stringWithFormat:@"http://www.bing.com%@_1920x1200.jpg",value];
		NSArray *splitImgUrl = [imgUrlStr componentsSeparatedByString:@"/"];
		NSLog(@"Found image URL: %@", imgUrlStr);
		imgDownloadName = [[splitImgUrl objectAtIndex: [splitImgUrl count] -1] retain];
		imgPath = [[[imgDownloadLoc stringByExpandingTildeInPath] stringByAppendingPathComponent:imgDownloadName] retain];
	}
	else if(foundCopyright == YES) {	
		[copyrightStr appendString:value];
	}
}

-(void)parser:(NSXMLParser *)parser foundIgnorableWhitespace:(NSString *)value {
	NSLog(@"Found whitespace: '%@'", value);
}

-(void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    NSLog(@"Error parsing XML: %@", [parseError localizedDescription]);
}

-(void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError {
    NSLog(@"Error parsing XML: %@", [validationError localizedDescription]);
}

- (void)setURL:(NSURL *)theUrl {
	if (xmlUrl != theUrl) {
		[xmlUrl release];
		xmlUrl = [theUrl retain];
		NSString *displayXmlUrl = [[NSString alloc] initWithString:[xmlUrl absoluteString]];
		NSLog(@"Url set to: %@",displayXmlUrl);
		[displayXmlUrl release];
    }
}

- (void)setData:(NSData *)theData encoding:(NSString *)encoding {
    if (data != theData) {
        [data release];
        data = [theData retain];
        
        // NSURLResponse's encoding is an IANA string. Use CF utilities to convert it to a CFStringEncoding then a NSStringEncoding
        NSStringEncoding nsEncoding = NSUTF8StringEncoding; // default to UTF-8
        if (encoding) {
            CFStringEncoding cfEncoding = CFStringConvertIANACharSetNameToEncoding((CFStringRef)encoding);
            if (cfEncoding != kCFStringEncodingInvalidId) {
                nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding);
            }
        }
        NSString *displayString = [[NSString alloc] initWithData:data encoding:nsEncoding];
		NSLog(@"Data set to: %@", displayString);
        [displayString release];
    }
}

- (void)setDocument:(NSXMLDocument *)doc {
    if (document != doc) {
        [document release];
        document = [doc retain];
    }
}

// ------------- The Download ------------- //

-(BOOL)imageExists:(id)sender
{	
	NSFileManager* fileManager = [[[NSFileManager alloc] init] autorelease];
	[self saveAppState:nil];
	if ([fileManager fileExistsAtPath: imgPath]){ 
		NSLog(@"File exists.");
		
		NSAlert* msgBox = [[[NSAlert alloc] init] autorelease];
        [msgBox setMessageText: @"You already have the most recent image."];
        [msgBox addButtonWithTitle: @"OK"];
        [msgBox runModal];
		
		return 1;
	} else {
		NSLog(@"File does not exist.");
		[self startDownloadingURL:nil];
		return 0;
	}
}

-(void)startDownloadingURL:(id)sender
{
	// Create the request.	
	NSURL* imgUrl = [NSURL URLWithString:imgUrlStr];
	NSURLRequest *request = [NSURLRequest requestWithURL:imgUrl];
												
	// Create the connection with the request and start loading the data.
	NSURLDownload *theDownload = [[NSURLDownload alloc] initWithRequest:request delegate:self];
	
	if (theDownload) {
		[theDownload setDestination:imgPath allowOverwrite:YES];
	} else {
		NSLog(@"Failed to download image.");
	}
}

-(void)download:(NSURLDownload *)download didFailWithError:(NSError *)error
{
	[download release];		// Release the connection.
	
	NSLog(@"Failed to download image. Error - %@ %@",
		[error localizedDescription],
		[[error userInfo] objectForKey:NSURLErrorFailingURLStringErrorKey]);
}

-(void)downloadDidFinish:(NSURLDownload *)download
{
	[download release];		// Release the connection.
	
	// Do something with the data.
	NSLog(@"Successfully downloaded image.");

	[self setDesktopBackground:nil];
}

// ------------ The Background ------------ //

- (void)setDesktopBackground:(id)sender
{
	curScreen = [NSScreen mainScreen];
	NSError *error = nil;
	
	NSURL *pathToImg = [NSURL fileURLWithPath:imgPath];
	NSLog(@"Path to downloaded image: %@",pathToImg);
	[[NSWorkspace sharedWorkspace] setDesktopImageURL:pathToImg forScreen:curScreen options:nil error:&error];
	if (error) {
		NSLog(@"Failed to set desktop background: %@", [error localizedDescription]);
	}
}


@end
