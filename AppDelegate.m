/**
 *  AppDelegate.m
 *  BingDesktop
 *
 *  Created by abradbury on 20/02/2013.
 *  Copyright 2015 abradbury. All rights reserved.
 * 
 *  Downloads the latest Bing homepage wallpaper and sets it as the user's 
 *  desktop wallpaper.
 *  
 *  Gets the previous state of the program, i.e. the previously downloaded 
 *  image and copyright information. Then waits for an internet connection 
 *  before determining the URL to the latest wallpaper and downloading it.
 *
 *  TODO: Add a random menu item that randomly selects one of the other Bing 
 *  desktop items if the user isn't happy with the current one.
 */

#import "AppDelegate.h"

@implementation AppDelegate

/**
 *	Initial application configuration.
 */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
	xmlLocation = @"https://www.bing.com/hpimagearchive.aspx?format=xml&idx=0&n=1&mbl=0&mkt=en-ww";
	copyrightStr = [[NSMutableString alloc] init];
	imgDownloadLoc = @"~/Pictures/Bing Desktop/";
	imgDownloadName = @"bingImage.jpg";
    wallpaperSuccessfullyDownloadedAndSet = FALSE;
	imgPath = [[imgDownloadLoc stringByExpandingTildeInPath] stringByAppendingPathComponent:imgDownloadName];
	
    // TODO: Catch NSSystemClockDidChangeNotification as well
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
                                                          selector:@selector(resetTimers:)
                                                              name:NSWorkspaceDidWakeNotification
                                                            object:nil];
    
    // Catch when the user changes spaces/desktops to check the image
    [[[NSWorkspace sharedWorkspace] notificationCenter] addObserver:self
           selector:@selector(setDesktopBackground:)
               name:NSWorkspaceActiveSpaceDidChangeNotification
             object:[NSWorkspace sharedWorkspace]];
    
	[self getAppState];         // Gets the previous application state
    [self waitForInternet:nil]; // Start once internet connection is available
}

/********************************* Scheduling *********************************/

/**
 *  Based on example from http://stackoverflow.com/a/9046264/1433614
 * 
 *  @param  forTomrrow  True if timer is for tomorrow, false for today
 */
- (void)scheduleNextTimedAction:(BOOL)forTomorrow {
    NSDate* now = [NSDate date] ;
    NSLog(@"Current time: %@", now);
    
    NSDateComponents* tomorrowComponents = [NSDateComponents new] ;
    
    if(forTomorrow) {
        NSLog(@"Setting timer for tomorrow");
        tomorrowComponents.day = 1 ;
    } else {
        NSLog(@"Setting timer for today");
        tomorrowComponents.day = 0 ;
    }
    
    NSCalendar* calendar = [NSCalendar currentCalendar] ;
    NSDate* tomorrow = [calendar dateByAddingComponents:tomorrowComponents toDate:now options:0] ;
    
    NSDateComponents* tomorrowAt8AMComponents = [calendar components:(NSEraCalendarUnit|NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:tomorrow] ;
    tomorrowAt8AMComponents.hour = 7 ;
    tomorrowAt8AMComponents.minute = 5 ;
    NSDate* tomorrowAt8AM = [calendar dateFromComponents:tomorrowAt8AMComponents] ;
    
    NSLog(@"Setting timer for: %@", tomorrowAt8AM);
    
    // now create a timer to fire at the next midnight, to call
    // our periodic function. NB: there's no convenience factory
    // method that takes an NSDate, so we'll have to alloc/init
    startProgramTimer = [[NSTimer alloc]
                      initWithFireDate:tomorrowAt8AM
                      interval:0.0 // we're not going to repeat, so...
                      target:self
                      selector:@selector(doTimedAction:)
                      userInfo:nil
                      repeats:NO];

    // schedule the timer on the current run loop
    [[NSRunLoop currentRunLoop] addTimer:startProgramTimer forMode:NSDefaultRunLoopMode];

    // timer is retained by the run loop, so we can forget about it
    [startProgramTimer release];
    [tomorrowComponents release];
}

- (void)doTimedAction:(NSTimer *)timer {
    NSLog(@"do action");
    
    [self waitForInternet:nil];
    [self scheduleNextTimedAction:TRUE];
}

- (void) resetTimers: (NSNotification*) note {
    NSLog(@"Woken from sleep");
    
    // Clear Timers
    if ([startProgramTimer isValid]){
        [startProgramTimer invalidate];
        startProgramTimer = nil;
    }
    
    if ([self hasTodaysWallaperBeenDownloaded]) {
        // If wallpaper downloaded, set timer for tomorrow
        NSLog(@"Wallpaper has already been downloaded for today");
        [self scheduleNextTimedAction:(TRUE)];
    } else {
        // If wallpaper not downloaded, check what time it is
        // TODO: Check is time is after 8am
        NSLog(@"Wallpaper has not been downloaded for today");
        
        if ([self isAfterWallpaperDownloadTime]) {
            // If now is after download time, download & set timer for tomorrow
            NSLog(@"Current time is after wallpaper download time");
            [self waitForInternet:nil];
            [self scheduleNextTimedAction:TRUE];
        } else {
            // If now is before download time, set timer for later today
            NSLog(@"Current time is before wallpaper download time");
            [self scheduleNextTimedAction:FALSE];
        }
    }
}

/**
 *  @return     True if the wallpaper was downloaded today, false otherwise
 */
-(BOOL)hasTodaysWallaperBeenDownloaded {
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate * now = [NSDate date];
    NSDate * storedDate = [self dateFromString:[[NSUserDefaults standardUserDefaults] stringForKey:@"com.bingDesktop.wallpaperLastDownloaded"] :@"MM/dd/yyyy hh:mm a"];
    
    NSLog(@"Current time: %@", now);
    NSLog(@"Stored date:  %@", storedDate);
    
    unsigned unitFlags = NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay;
    NSDateComponents* comp1 = [calendar components:unitFlags fromDate:now];
    NSDateComponents* comp2 = [calendar components:unitFlags fromDate:storedDate];
    
    return [comp1 day]   == [comp2 day] &&
           [comp1 month] == [comp2 month] &&
           [comp1 year]  == [comp2 year];
}


-(NSDate*)dateFromString:(NSString*) dateString :(NSString*) dateFormat {
    NSDateFormatter *dateFmt = [[NSDateFormatter alloc] init];
    [dateFmt setDateFormat: dateFormat];
    NSDate *dateToReturn = [dateFmt dateFromString: dateString];
    [dateFmt release];
    return dateToReturn;
}

-(BOOL)isAfterWallpaperDownloadTime {
    NSCalendar* calendar = [NSCalendar currentCalendar];
    NSDate * now = [NSDate date];
    
    NSDateComponents *components = [calendar components: NSYearCalendarUnit|
                                    NSMonthCalendarUnit|
                                    NSDayCalendarUnit
                                    fromDate:now];
    [components setHour:8];
    [components setMinute:5];
    NSDate *reference = [calendar dateFromComponents:components];
    
    unsigned unitFlags = NSCalendarUnitHour | NSCalendarUnitMinute;
    NSDateComponents* comp1 = [calendar components:unitFlags fromDate:now];
    NSDateComponents* comp2 = [calendar components:unitFlags fromDate:reference];
    
    return [comp1 hour] > [comp2 hour] && [comp1 minute] > [comp2 minute];
}

/***************************** Application State ******************************/

/**
 * Save the current image path and copyright information. Used when launching
 * the app again after at least 1 previous opening to display correct copyright
 * information for current wallpaper.
 */
-(void)saveAppState {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    // Store the copyright string
    [defaults setObject:copyrightStr forKey:@"com.bingDesktop.copyright"];
    
    if ([copyrightStr isEqualToString:[defaults stringForKey:@"com.bingDesktop.copyright"]]) {
        NSLog(@"Copyright string saved");
    } else {
        NSLog(@"Copyright string not saved.");
    }
    
    // Store the date that the last wallpaper was downloaded
    if (wallpaperSuccessfullyDownloadedAndSet) {
        NSString *wallpaperDownloadedDate = [self getTodaysDate];
        
        [defaults setObject: wallpaperDownloadedDate forKey:@"com.bingDesktop.wallpaperLastDownloaded"];
        wallpaperSuccessfullyDownloadedAndSet = FALSE;
        
        if ([wallpaperDownloadedDate isEqualToString:[defaults stringForKey:@"com.bingDesktop.wallpaperLastDownloaded"]]) {
            NSLog(@"Wallpaper last downloaded date saved.");
        } else {
            NSLog(@"Wallpaper last downloaded date not saved.");
        }
    }
    
    // Store the image path
    [defaults setObject:imgPath forKey:@"com.bingDesktop.imagePath"];
    
    if ([imgPath isEqualToString:[defaults stringForKey:@"com.bingDesktop.imagePath"]]) {
        NSLog(@"Image path saved");
    } else {
        NSLog(@"Image path not saved.");
    }
}

-(NSString *)getTodaysDate {
    NSDateFormatter *dateFormatter=[[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"MM/dd/yyyy hh:mm a"];
    NSString *dateString = [dateFormatter stringFromDate:[NSDate date]];
    [dateFormatter release];
    return dateString;
}

/**
 *	Gets the previous state of the application, such as the copyright string
 *	and background image.
 *
 *  @param  sender  desciption
 */
-(void)getAppState {
    NSUserDefaults* defaults = [NSUserDefaults standardUserDefaults];
    
    // Remove old copyright and image defaults
    [defaults removeObjectForKey:@"copyright"];
    [defaults removeObjectForKey:@"image"];
    
    // Get previous copyright string
    NSString *savedCopyright = [defaults stringForKey:@"com.bingDesktop.copyright"];
    if (savedCopyright) {
        [copyrightStr setString:savedCopyright];
        [statusItem setToolTip:copyrightStr];
        NSLog(@"Previous copyright string found.");
    } else {
        NSLog(@"No previous copyright string found.");
    }
}

/*************************** Internet Availability ****************************/

/**
 *  Wait until there is an internet connection before continuing with the 
 *  application and attempting to download the XML document and image. Checks 
 *  every 5 seconds, but does not cause the UI to hang. Uses the reachability 
 *  API from Apple's iOS work.
 */
-(IBAction)waitForInternet:(id)sender {
    
    [NSTimer scheduledTimerWithTimeInterval:5.0
                                     target:self
                                   selector:@selector(connected:)
                                   userInfo:nil
                                    repeats:YES];
}

- (void)connected:(NSTimer*)t {
    Reachability *reachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [reachability currentReachabilityStatus];
    if (networkStatus != NotReachable) {
        [t invalidate];
        NSLog(@"Internet connection available.");
        [self getXML];
    } else {
        NSLog(@"Internet connection not available.");
    }
}

/******************************** XML Parsing *********************************/

/**
 *  Download the XML document that indicates the path for the current day's 
 *  image, which will be downloaded later.
 *
 *  @param  sender  description
 * 
 *  @return         TRUE if the XML file was downloaded, FALSE otherwise
 */
- (void)getXML {
    xmlUrl = [NSURL URLWithString:xmlLocation];
	
    // Clear copyright string
    // TODO: Move to another method
    // TODO: Clear image path?
	[copyrightStr setString:@""];
	
	// Asynchronously get the data
    NSURLSessionDataTask *dataXmlTask = [[NSURLSession sharedSession]
        dataTaskWithURL:xmlUrl completionHandler:^(NSData *dataReceived, NSURLResponse *response, NSError *error) {
            
            urlResponse = [response retain];
            
            if (error) {
                NSLog(@"%@", [error localizedDescription]);
            } else {
                NSLog(@"Successfully received %lu bytes of data for XML file.",
                      (unsigned long)[dataReceived length]);
                
                data = dataReceived;
                
                if (!dataReceived) {
                    NSLog(@"Error getting XML - no data received.");
                    [self setDocument:nil]; // Clear out old value
                }
                
                [self parseXmlFromURL];
            }
    }];
    
    // Tasks from NSURLSession start in a suspended state. Start the task here.
    [dataXmlTask resume];
}

/**
 *  Parse downloaded XML data to extract the URL of the current day's image.
 */
-(void)parseXmlFromURL {
    NSLog(@"Parsing XML...");
    
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:data];
	[xmlParser setDelegate:self];
	[xmlParser setShouldResolveExternalEntities:NO];
	
	BOOL parseResult = [xmlParser parse];
    
    if (parseResult == NO) {
		NSLog(@"...Error parsing XML.");
    } else {
		NSLog(@"...XML parsed successfully.");
    }
	
    // Release the parser from memory
	[xmlParser release];
    
    // Set copyright string, save app state
    [statusItem setToolTip:copyrightStr];
    
    // If image is not downloaded, then download it and set it as the desktop
    // background. Else, set it as the desktop background.
    if (!([self isImageDownloaded])) {
        [self startDownloadingURL];
    } else if (!([self isImageSetAsWallpaper])) {
        [self setDesktopBackground:nil];
        [self showNotification:nil];
    }
}

/**
 *  Called when the XML parser finds a starting tag
 */
-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary *)attributeDict {
	if([elementName isEqualToString:@"urlBase"])
		foundImgUrl = YES;
	else if([elementName isEqualToString:@"copyright"])
		foundCopyright = YES;
}

/**
 *  Called when the XML parser finds an ending tag
 */
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    if([elementName isEqualToString:@"urlBase"])
		foundImgUrl = NO;
	else if([elementName isEqualToString:@"copyright"])
		foundCopyright = NO;
}

/**
 *  Called when the XML parse find characters between tags
 */
-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)value {
	if(foundImgUrl == YES) {
		imgUrlStr = [NSString stringWithFormat:@"https://www.bing.com%@_1920x1200.jpg",value];
		NSArray *splitImgUrl = [imgUrlStr componentsSeparatedByString:@"/"];
		NSLog(@"Found image URL: %@", imgUrlStr);
		imgDownloadName = [[splitImgUrl objectAtIndex: [splitImgUrl count] -1] retain];
		imgPath = [[[imgDownloadLoc stringByExpandingTildeInPath] stringByAppendingPathComponent:imgDownloadName] retain];
	} else if(foundCopyright == YES) {
		[copyrightStr appendString:value];
	}
}

-(void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError {
    NSLog(@"Error parsing XML: %@", [parseError localizedDescription]);
}

-(void)parser:(NSXMLParser *)parser validationErrorOccurred:(NSError *)validationError {
    NSLog(@"Error parsing XML: %@", [validationError localizedDescription]);
}

/******************************* Image Download *******************************/

-(void)startDownloadingURL {
    NSURLSessionDownloadTask *downloadImageTask = [[NSURLSession sharedSession]
        downloadTaskWithURL:[NSURL URLWithString:imgUrlStr]
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            
            if (error) {
                NSLog(@"%@", [error localizedDescription]);
            } else {
                NSLog(@"Successfully downloaded image.");
                NSData *imageData = [NSData dataWithContentsOfURL: location];
                [imageData writeToFile:imgPath atomically:NO];
                
                [self setDesktopBackground:nil];
            }
        }];
    
    [downloadImageTask resume];
}

/**************************** Wallpaper Background ****************************/

- (void)setDesktopBackground:(NSNotification *)aNotification {
    NSWorkspace *workspace = [NSWorkspace sharedWorkspace];
    NSScreen *screen = [NSScreen mainScreen];
	NSError *error = nil;
    
    NSDictionary *screenOptions = [workspace desktopImageOptionsForScreen: screen];
    NSURL *pathToImg = [NSURL fileURLWithPath:imgPath];
    
    NSArray *screens = [NSScreen screens];
    NSScreen *iterScreen;
    
    // Apply wallpaper to every physical screen
    // Currently not possible to set all desktops
    for (iterScreen in screens) {
        NSURL *curr = [workspace desktopImageURLForScreen: iterScreen];
        if (![curr isEqual:pathToImg]) {
            NSLog(@"Setting desktop background...");
            
            [workspace setDesktopImageURL:pathToImg
                                forScreen:iterScreen
                                  options:screenOptions
                                    error:&error];
            
            if (error) {
                NSLog(@"Failed to set desktop background: %@", [error localizedDescription]);
            }
        } else {
            NSLog(@"Not setting desktop background...");
        }
    }
    
    // TODO: Or errors?
	if (error) {
		NSLog(@"Failed to set desktop background: %@", [error localizedDescription]);
    } else {
        wallpaperSuccessfullyDownloadedAndSet = TRUE;
        [self saveAppState];
    }
}

- (IBAction)showNotification:(id)sender{
    NSUserNotification *notification = [[NSUserNotification alloc] init];
    notification.title = @"New wallpaper downloaded";
    notification.informativeText = copyrightStr;
    notification.soundName = nil;
    
    [[NSUserNotificationCenter defaultUserNotificationCenter] deliverNotification:notification];
}

/************************************ Menu ************************************/

/*
 *	Creates the menu.
 */
-(void)awakeFromNib{
    // Create the NSStatusItem, add the statusMenus to it and enable highlighting
    statusItem = [[[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength] retain];
    [statusItem setMenu:statusMenu];
    [statusItem setHighlightMode:YES];
    
    // Define the main image for the statusItem
    statusItemImage = [NSImage imageNamed:@"logo-black"];
    if( !statusItemImage ) {
        NSLog(@"ERROR: Could not load the image for 'logo-black.png'");
    } else {
        [statusItem setImage:statusItemImage];
    }
    
    // Define the image to use when the statusItem is highlighted
    statusItemImageAlt = [NSImage imageNamed:@"logo-white"];
    if( !statusItemImageAlt ) {
        NSLog(@"ERROR: Could not load the image for 'logo-white.png'");
    } else {
        [statusItem setAlternateImage:statusItemImageAlt];
    }
}

/*********************************** Other ************************************/

/**
 *  Checks if the image parsed from the XML has already been downloaded.
 */
-(BOOL)isImageDownloaded {
    NSFileManager* fileManager = [[[NSFileManager alloc] init] autorelease];
    
    if ([fileManager fileExistsAtPath: imgPath]){
        NSLog(@"Image already exists.");
        return TRUE;
    } else {
        NSLog(@"Image does not exist.");
        return FALSE;
    }
}

/**
 *  Checks to see if the image is the current wallpaper.
 */
-(BOOL)isImageSetAsWallpaper {
    NSURL *currentWallpaperUrl = [[NSWorkspace sharedWorkspace] desktopImageURLForScreen:[NSScreen mainScreen]];
    NSString *currentWallpaperString = [currentWallpaperUrl absoluteString];
    NSArray *currentWallpaperArray = [currentWallpaperString componentsSeparatedByString:@"/"];
    NSString *currentWallpaper = [[currentWallpaperArray objectAtIndex: [currentWallpaperArray count] -1] retain];
    
    NSLog(@"Current wallpaper: %@", currentWallpaper);
    
    if ([currentWallpaper isEqualToString:imgDownloadName]) {
        [currentWallpaper release];
        NSLog(@"Image already set as wallpaper.");
        return TRUE;
    } else {
        [currentWallpaper release];
        NSLog(@"Image not set as wallpaper.");
        return FALSE;
    }
}

- (void)dealloc {
    [statusItemImage release];
    [statusItemImageAlt release];
    [super dealloc];
}

- (void)setDocument:(NSXMLDocument *)doc {
    if (document != doc) {
        [document release];
        document = [doc retain];
    }
}

@end
