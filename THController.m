//
//  THController.m
//  TwitHunter
//
//  Created by Nicolas Seriot on 19.04.09.
//  Copyright 2009 Sen:te. All rights reserved.
//

#import "THController.h"
#import "Tweet.h"
#import "User.h"
#import "TextRule.h"
#import "NSManagedObject+TH.h"
#import "TweetCollectionViewItem.h"
#import "MGTwitterEngine+TH.h"

@implementation THController

@synthesize tweetSortDescriptors;
@synthesize tweetFilterPredicate;
@synthesize tweetText;
@synthesize requestsIDs;
@synthesize isConnecting;
@synthesize requestStatus;
@synthesize timer;
@synthesize twitterEngine;

- (IBAction)updateViewScore:(id)sender {
	[cumulativeChartView setScore:[sender intValue]];
}

- (NSMutableArray *)predicatesWithoutScore {
	NSMutableArray *a = [NSMutableArray array];
	
	NSNumber *hideRead = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.hideRead"];
	if([hideRead boolValue]) {
		NSPredicate *p2 = [NSPredicate predicateWithFormat:@"isRead == NO"];
		[a addObject:p2];
	}
	
	NSNumber *hideURLs = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.hideURLs"];
	if([hideURLs boolValue]) {
		NSPredicate *p3 = [NSPredicate predicateWithFormat:@"text CONTAINS %@", @"http://"];
		NSPredicate *p4 = [NSCompoundPredicate notPredicateWithSubpredicate:p3]; 
		[a addObject:p4];
	}
	
	return a;
}

- (void)updateSliderView {
	[cumulativeChartView setTweetsCount:[Tweet allObjectsCount]];
	
	for(NSUInteger i = 0; i <= 100; i++) {
		NSUInteger nbTweets = [Tweet nbOfTweetsForScore:[NSNumber numberWithUnsignedInt:i] andSubpredicates:[self predicatesWithoutScore]];
		[cumulativeChartView setNumberOfTweets:nbTweets forScore:i];
	}
	
	[cumulativeChartView setNeedsDisplay:YES];
	[cumulativeChartView sendValuesToDelegate];
}

- (IBAction)updateTweetScores:(id)sender {
	NSLog(@"-- update scores");
	
	// user score
	for(Tweet *t in [Tweet allObjects]) {
		NSInteger score = 50 + [t.user.score intValue];
		if(score < 0) score = 0;
		if(score > 100) score = 100;		
		t.score = [NSNumber numberWithInt:score];
	}

	// text score
	for(TextRule *rule in [TextRule allObjects]) {
		NSArray *tweetsContainingKeyword = [Tweet tweetsContainingKeyword:rule.keyword];
		for(Tweet *t in tweetsContainingKeyword) {
			NSInteger score = [t.score intValue];
			score += [rule.score intValue];
			if(score < 0) score = 0;
			if(score > 100) score = 100;
			t.score = [NSNumber numberWithInt:score];
		}
	}
	
	NSError *error = nil;
	[[Tweet moc] save:&error];
	if(error) {
		NSLog(@"-- error:%@", error);
	}
	
	[self updateSliderView];
}

- (void)updateTweetFilterPredicate {
	NSMutableArray *predicates = [self predicatesWithoutScore];

	NSNumber *score = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.score"];
	NSPredicate *p1 = [NSPredicate predicateWithFormat:@"score >= %@", score];
	[predicates addObject:p1];
		
	self.tweetFilterPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:predicates];
	
	[tweetArrayController rearrangeObjects];
	
	[self updateSliderView];
}

- (id)init {
	if (self = [super init]) {
		NSSortDescriptor *sd = [[NSSortDescriptor alloc] initWithKey:@"date" ascending:NO];
		self.tweetSortDescriptors = [NSArray arrayWithObject:sd];
		[sd release];

		NSString *defaultsPath = [[NSBundle mainBundle] pathForResource:@"Defaults" ofType:@"plist"];
		NSDictionary *defaults = [NSDictionary dictionaryWithContentsOfFile:defaultsPath];
		[[NSUserDefaults standardUserDefaults] registerDefaults:defaults];
		
		self.requestsIDs = [NSMutableSet set];
		
		[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.score" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:NULL];
		[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hideRead" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:NULL];
		[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.hideURLs" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:NULL];
		[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self forKeyPath:@"values.updateFrequency" options:NSKeyValueObservingOptionOld|NSKeyValueObservingOptionNew context:NULL];
	}
	
	return self;
}

- (void)timerTick {
	[self update:self];
}

- (void)resetTimer {
	if(self.timer) {
		[timer invalidate];
	}
	
	NSTimeInterval seconds = [[[NSUserDefaults standardUserDefaults] valueForKey:@"updateFrequency"] doubleValue] * 60;
	
	if(seconds < 59.9) seconds = 60.0;
	
	self.timer = [NSTimer scheduledTimerWithTimeInterval:seconds
												  target:self
												selector:@selector(timerTick)
												userInfo:NULL
												 repeats:YES];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
	//NSLog(@"-- keyPath %@", keyPath);
	
	if(object == [NSUserDefaultsController sharedUserDefaultsController] &&
	   [[NSArray arrayWithObjects:@"values.score", @"values.hideRead", @"values.hideURLs", nil] containsObject:keyPath]) {
		[self updateTweetFilterPredicate];
		return;
	}

	if(object == [NSUserDefaultsController sharedUserDefaultsController] &&
	   [[NSArray arrayWithObjects:@"values.updateFrequency", nil] containsObject:keyPath]) {
		[self resetTimer];
		return;
	}
	
	[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

- (IBAction)updateCredentials:(id)sender {
	[preferences close];
	
	NSString *username = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.username"];
	NSString *password = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.password"];
	[twitterEngine setUsername:username password:password];
	
	[self update:self];
}

- (IBAction)tweet:(id)sender {
	self.requestStatus = nil;
	NSString *requestID = [twitterEngine sendUpdate:tweetText];
	if(requestID) {
		[requestsIDs addObject:requestID];
	}
	self.tweetText = nil;
}

- (IBAction)update:(id)sender {
	NSLog(@"-- update");
	
	self.requestStatus = nil;
	self.isConnecting = [NSNumber numberWithBool:YES];
	
	NSNumber *lastKnownID = [[NSUserDefaults standardUserDefaults] valueForKey:@"highestID"]; 
	NSLog(@"-- found lastKnownID: %@", lastKnownID);
	
	if(lastKnownID && [lastKnownID unsignedLongLongValue] != 0) {
		NSLog(@"-- fetch timeline since ID: %@", lastKnownID);
		NSString *requestID = [twitterEngine getHomeTimelineSinceID:[lastKnownID unsignedLongLongValue] withMaximumID:0 startingAtPage:0 count:100];
		[requestsIDs addObject:requestID];
	} else {
		NSLog(@"-- fetch timeline last 50");
		NSArray *requestIDs = [twitterEngine getHomeTimeline:50];
		[requestsIDs addObjectsFromArray:requestIDs];		
	}
}

- (void)didChangeTweetReadStatusNotification:(NSNotification *)aNotification {
	Tweet *tweet = [[aNotification userInfo] objectForKey:@"Tweet"];
	NSNumber *score = tweet.score;
	
	NSUInteger nbTweets = [Tweet nbOfTweetsForScore:score andSubpredicates:[self predicatesWithoutScore]];
	
	[cumulativeChartView setNumberOfTweets:nbTweets forScore:[score unsignedIntegerValue]];
	[cumulativeChartView setNeedsDisplay:YES];
	[cumulativeChartView sendValuesToDelegate];
	
	[tweetArrayController rearrangeObjects];	
}

- (void)awakeFromNib {
	NSLog(@"awakeFromNib");
	
	cumulativeChartView.delegate = self;
	
	NSNumber *currentScore = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.score"];
	[cumulativeChartView setScore:[currentScore integerValue]];
	
	[self updateTweetFilterPredicate];
	
	[self updateTweetScores:self];

	[collectionView setMaxNumberOfColumns:1];
	
	self.twitterEngine = [[[MGTwitterEngine alloc] initWithDelegate:self] autorelease];
	
	NSString *username = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.username"];
	NSString *password = [[NSUserDefaultsController sharedUserDefaultsController] valueForKeyPath:@"values.password"];
	
	if([username length] == 0 || [password length] == 0) {
        NSLog(@"You forgot to specify your username/password!");
		[preferences makeKeyAndOrderFront:self];
		return;
	}
	
    [twitterEngine setUsername:username password:password];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didChangeTweetReadStatusNotification:) name:@"DidChangeTweetReadStateNotification" object:nil];
	
	[self update:self];
	
	[self resetTimer];	
}

- (IBAction)markAllAsRead:(id)sender {
	[[tweetArrayController arrangedObjects] setValue:[NSNumber numberWithBool:YES] forKey:@"isRead"];
	[tweetArrayController rearrangeObjects];
}

- (IBAction)markAllAsUnread:(id)sender {
	[[tweetArrayController arrangedObjects] setValue:[NSNumber numberWithBool:NO] forKey:@"isRead"];
	[tweetArrayController rearrangeObjects];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[twitterEngine release];
	[timer release];
	[tweetSortDescriptors release];
	[tweetFilterPredicate release];
	[tweetText release];
	[requestsIDs release];
	[isConnecting release];
	[requestStatus release];
	[requestsIDs release];
	
	[super dealloc];
}

#pragma mark MGTwitterEngineDelegate

- (void)requestSucceeded:(NSString *)requestIdentifier {
	NSLog(@"requestSucceeded:%@", requestIdentifier);

	self.requestStatus = nil;
	[requestsIDs removeObject:requestIdentifier];
	self.isConnecting = [NSNumber numberWithBool:[requestsIDs count] != 0];
}

- (void)requestFailed:(NSString *)requestIdentifier withError:(NSError *)error {
	NSLog(@"requestFailed:%@ withError:%@", requestIdentifier, [error localizedDescription]);

	self.requestStatus = [error localizedDescription];
	[requestsIDs removeObject:requestIdentifier];
	self.isConnecting = [NSNumber numberWithBool:[requestsIDs count] != 0];
}

- (void)statusesReceived:(NSArray *)statuses forRequest:(NSString *)identifier {
	NSLog(@"-- statusesReceived: %d", [statuses count]);
	
	self.requestStatus = nil;
	[requestsIDs removeObject:identifier];
	self.isConnecting = [NSNumber numberWithBool:[requestsIDs count] != 0];
	
	MGTwitterEngineID highestID = [Tweet saveTweetsFromDictionariesArray:statuses];
	
	NSNumber *highestKnownID = [NSNumber numberWithUnsignedLongLong:highestID];
	
	if(highestID != 0) {
		[[NSUserDefaults standardUserDefaults] setObject:highestKnownID forKey:@"highestID"];
		NSLog(@"-- stored highestID: %@", highestKnownID);
	}
	
	[self updateTweetScores:self];
}

- (void)directMessagesReceived:(NSArray *)messages forRequest:(NSString *)identifier {
	NSLog(@"directMessagesReceived:%@ forRequest:", messages, identifier);
}

- (void)userInfoReceived:(NSArray *)userInfo forRequest:(NSString *)identifier {
	NSLog(@"userInfoReceived:%@ forRequest:", userInfo, identifier);
}

- (void)connectionFinished {
	NSLog(@"connectionFinished");
}

- (void)miscInfoReceived:(NSArray *)miscInfo forRequest:(NSString *)connectionIdentifier {
	NSLog(@"miscInfoReceived:%@ forRequest:%@", miscInfo, connectionIdentifier);
}

- (void)imageReceived:(NSImage *)image forRequest:(NSString *)connectionIdentifier {
	NSLog(@"imageReceived:%@ forRequest:%@", image, connectionIdentifier);
}

#pragma mark CumulativeChartViewDelegate

- (void)didSlideToScore:(NSUInteger)aScore cumulatedTweetsCount:(NSUInteger)cumulatedTweetsCount {
	//NSLog(@"-- didSlideToScore:%d cumulatedTweetsCount:%d", aScore, cumulatedTweetsCount);
	[expectedNbTweetsLabel setStringValue:[NSString stringWithFormat:@"%d", cumulatedTweetsCount]];
	[expectedScoreLabel setStringValue:[NSString stringWithFormat:@"%d", aScore]];
}

@end
