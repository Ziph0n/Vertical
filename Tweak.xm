#import "MediaRemote.h"
#import <Cephei/HBPreferences.h>
#import "CBAutoScrollLabel/CBAutoScrollLabel.h"
#import <MediaPlayer/MediaPlayer.h>
#import "RSPlayPauseButton/RSPlayPauseButton.h"

#define DEGREES_TO_RADIANS(degrees) (( degrees) / 180.0 * M_PI)

@interface MPUMediaControlsVolumeView : UIView
@property (nonatomic, readonly) UISlider *slider;
- (id)initWithStyle:(int)arg1;
@end

@interface MPDetailScrubController : NSObject
@property (nonatomic) BOOL detailedScrubbingEnabled;
@end

@interface MPUChronologicalProgressView : UIView
@property (nonatomic) double currentTime;
@property (nonatomic) double totalDuration;
@property (nonatomic, assign) id delegate;
@property (nonatomic) BOOL scrubbingEnabled;
- (void)setScrubbingEnabled:(BOOL)arg1;
- (id)initWithStyle:(int)style;
@end

@interface SBLockScreenView : UIView
- (void)verticalStartTimer;
- (void)verticalUpdateNowPlaying;
@end

@interface MPUNowPlayingController : NSObject
- (id)nowPlayingAppDisplayID;
@end

static HBPreferences *preferences;
static BOOL enabled;
static NSInteger playerStyle;
static NSInteger playerWidth;

static BOOL lsVisible;
static NSTimer *_timer;
static NSNotificationCenter *nc = nil;
static id delegate;
static BOOL wantsToPlay = FALSE;

static UIView *playerView;
static UIImageView *playerArtwork;
static RSPlayPauseButton *playPauseButton;

static UIView *nowPlayingView;
static UIImageView *nowPlayingViewArtwork;
static CBAutoScrollLabel *titleLabel;
static CBAutoScrollLabel *artistLabel;
static MPUChronologicalProgressView *trackProgressView;

%hook SBLockScreenView

- (id)initWithFrame:(CGRect)arg1 {
    id r = %orig;
    if (enabled) {
        if (r) {
            lsVisible = FALSE;
        }
    }
    return r;
}

- (void)layoutSubviews {
	%orig;
    if (enabled) {
        if (lsVisible == FALSE) {

			if (nc == nil) {
				nc = [NSNotificationCenter defaultCenter];
		        [nc addObserver:self selector:@selector(verticalUpdateNowPlaying) name:(NSString *)kMRMediaRemoteNowPlayingInfoDidChangeNotification object:nil];
		        [nc addObserver:self selector:@selector(verticalUpdateNowPlayingStatus) name:(NSString *)kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification object:nil];
			}

			playerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 300, playerWidth, playerWidth * 3.5)] autorelease];
			UIBlurEffect *playerViewBlurEffect = 0;
			if (playerStyle == 1) {
				playerViewBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
				UIVisualEffectView *playerViewBlurEffectView = [[UIVisualEffectView alloc] initWithEffect:playerViewBlurEffect];
			    [playerViewBlurEffectView setFrame:playerView.bounds];
			    [playerView addSubview:playerViewBlurEffectView];
			} else if (playerStyle == 2) {
				playerViewBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
				UIVisualEffectView *playerViewBlurEffectView = [[UIVisualEffectView alloc] initWithEffect:playerViewBlurEffect];
			    [playerViewBlurEffectView setFrame:playerView.bounds];
			    [playerView addSubview:playerViewBlurEffectView];
			} else {
				playerView.backgroundColor = [UIColor redColor];
			}

			playerArtwork = [[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, playerWidth, playerWidth)] autorelease];
			//[playerArtwork.layer setCornerRadius:10.0f];
		    //[playerArtwork.layer setMasksToBounds:YES];
			playerArtwork.userInteractionEnabled = YES;
	        [playerView addSubview:playerArtwork];

			UITapGestureRecognizer *openNowPlayingViewTap = [[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(openNowPlayingView)] autorelease];
			openNowPlayingViewTap.numberOfTapsRequired = 1;
			[playerArtwork addGestureRecognizer:openNowPlayingViewTap];

            playPauseButton = [[RSPlayPauseButton alloc] initWithFrame:CGRectMake(10, 150, 50, 50)];
            playPauseButton.tintColor = [UIColor whiteColor];
            [playPauseButton addTarget:self action:@selector(playPauseButtonDidPress:) forControlEvents:UIControlEventTouchUpInside];
            [playerView addSubview:playPauseButton];

			MPUMediaControlsVolumeView *volumeView = [[[MPUMediaControlsVolumeView alloc] initWithStyle:2] autorelease];
			volumeView.frame = CGRectMake(-10, 180, 150, 50);
			volumeView.backgroundColor = [UIColor clearColor];
			CGAffineTransform transform = CGAffineTransformRotate(CGAffineTransformIdentity, DEGREES_TO_RADIANS(-90));
			volumeView.transform = transform;
			UISlider *volumeSlider = volumeView.slider;
			volumeSlider.maximumValueImage = nil;
			volumeSlider.minimumValueImage = nil;
			[playerView addSubview:volumeView];


			nowPlayingView = [[[UIView alloc] initWithFrame:CGRectMake(playerWidth + 100, 200, 400, 500)] autorelease];
			nowPlayingView.alpha = 0.0;
			UIBlurEffect *nowPlayingViewBlurEffect = 0;
			if (playerStyle == 1) {
				nowPlayingViewBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
				UIVisualEffectView *nowPlayingViewBlurEffectView = [[UIVisualEffectView alloc] initWithEffect:nowPlayingViewBlurEffect];
				[nowPlayingViewBlurEffectView setFrame:nowPlayingView.bounds];
				[nowPlayingView addSubview:nowPlayingViewBlurEffectView];
			} else if (playerStyle == 2) {
				nowPlayingViewBlurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
				UIVisualEffectView *nowPlayingViewBlurEffectView = [[UIVisualEffectView alloc] initWithEffect:nowPlayingViewBlurEffect];
				[nowPlayingViewBlurEffectView setFrame:nowPlayingView.bounds];
				[nowPlayingView addSubview:nowPlayingViewBlurEffectView];
			} else {
				nowPlayingView.backgroundColor = [UIColor redColor];
			}

			nowPlayingViewArtwork = [[[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 200, 200)] autorelease];
			//[playerArtwork.layer setCornerRadius:10.0f];
			//[playerArtwork.layer setMasksToBounds:YES];
			[nowPlayingView addSubview:nowPlayingViewArtwork];

			titleLabel = [[[CBAutoScrollLabel alloc] initWithFrame:CGRectMake(30, 300, 175, 20)] autorelease];
	        titleLabel.labelSpacing = 30;
	        titleLabel.pauseInterval = 3;
	        titleLabel.scrollSpeed = 7;
	        titleLabel.fadeLength = 5.f;
	        titleLabel.scrollDirection = CBAutoScrollDirectionLeft;
	        titleLabel.font = [titleLabel.font fontWithSize:20];
	        titleLabel.textColor = [UIColor whiteColor];
	        [nowPlayingView addSubview:titleLabel];

			artistLabel = [[[CBAutoScrollLabel alloc] initWithFrame:CGRectMake(30, 350, 175, 20)] autorelease];
	        artistLabel.labelSpacing = 30;
	        artistLabel.pauseInterval = 3;
	        artistLabel.scrollSpeed = 7;
	        artistLabel.fadeLength = 5.f;
	        artistLabel.scrollDirection = CBAutoScrollDirectionLeft;
	        artistLabel.font = [artistLabel.font fontWithSize:15];
	        artistLabel.textColor = [UIColor whiteColor];
	        [nowPlayingView addSubview:artistLabel];

			trackProgressView = [[MPUChronologicalProgressView alloc] initWithStyle:2];
            trackProgressView.bounds = CGRectMake(0, 0, 200, 10);
            trackProgressView.layer.position = CGPointMake(150, 120);
			delegate = MSHookIvar<id>(self, "_delegate");
			trackProgressView.delegate = (id)self;
            [nowPlayingView addSubview:trackProgressView];

            MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), ^(Boolean isPlay) {
                if (!isPlay) {
                    if (_timer) {
                        [_timer invalidate];
                         _timer = nil;
                    }
                    [playPauseButton setPaused:TRUE animated:YES];
                } else {
                    if (_timer) {
                        [_timer invalidate];
                         _timer = nil;
                    }
                    [playPauseButton setPaused:FALSE animated:YES];
                    [self verticalStartTimer];
                }
            });

			[self verticalUpdateNowPlaying];


            UIView *_foregroundLockView = MSHookIvar<UIView*>(self, "_foregroundLockView");
			[_foregroundLockView addSubview:playerView];
			[_foregroundLockView addSubview:nowPlayingView];

            lsVisible = TRUE;
    	}
    }
}

%new
- (void)verticalUpdateNowPlaying {
	MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), ^(Boolean isPlay) {
        if (!isPlay) {
            if (_timer) {
                [_timer invalidate];
                 _timer = nil;
            }
            [playPauseButton setPaused:TRUE animated:YES];
        } else {
            if (_timer) {
                [_timer invalidate];
                 _timer = nil;
            }
            [playPauseButton setPaused:FALSE animated:YES];
            [self verticalStartTimer];
        }
    });

	MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef result) {
        NSData* artwork = [(NSDictionary *)result objectForKey:(NSData *)( NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];
        UIImage* albumImage = [UIImage imageWithData:artwork];
        NSString *titleStr = [(NSDictionary *)result objectForKey:(NSString *)kMRMediaRemoteNowPlayingInfoTitle];
        NSString *artistStr = [(NSDictionary *)result objectForKey:(NSString *)kMRMediaRemoteNowPlayingInfoArtist];
        NSString *albumStr = [(NSDictionary *)result objectForKey:(NSString *)kMRMediaRemoteNowPlayingInfoAlbum];

		playerArtwork.image = albumImage;
		nowPlayingViewArtwork.image = albumImage;
		titleLabel.text = titleStr;
		if (albumStr != nil) {
			artistLabel.text = [NSString stringWithFormat:@"%@ ─ %@", artistStr, albumStr];
		} else {
			artistLabel.text = artistStr;
		}

        MPMediaItem *currentSong = [[MPMusicPlayerController systemMusicPlayer] nowPlayingItem];
        NSString *titlePlayerController = [currentSong valueForProperty:MPMediaItemPropertyTitle];
        if ([titleStr isEqual:titlePlayerController]) {
            trackProgressView.scrubbingEnabled = TRUE;
        } else {
            trackProgressView.scrubbingEnabled = FALSE;
        }

		HBLogDebug(@"albumImage = %@ / titleStr = %@ / artistStr = %@ / albumStr = %@", albumImage, titleStr, artistStr, albumStr);
	});
}

%new
- (void)verticalUpdateNowPlayingStatus {

    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), ^(Boolean isPlay) {
        if (!isPlay) {
            if (_timer) {
                [_timer invalidate];
                 _timer = nil;
            }
            [playPauseButton setPaused:TRUE animated:YES];
        } else {
            if (_timer) {
                [_timer invalidate];
                 _timer = nil;
            }
            [playPauseButton setPaused:FALSE animated:YES];
            [self verticalStartTimer];
        }
    });

	MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef result) {
        NSData* artwork = [(NSDictionary *)result objectForKey:(NSData *)( NSString *)kMRMediaRemoteNowPlayingInfoArtworkData];
        UIImage* albumImage = [UIImage imageWithData:artwork];
        NSString *titleStr = [(NSDictionary *)result objectForKey:(NSString *)kMRMediaRemoteNowPlayingInfoTitle];
        NSString *artistStr = [(NSDictionary *)result objectForKey:(NSString *)kMRMediaRemoteNowPlayingInfoArtist];
        NSString *albumStr = [(NSDictionary *)result objectForKey:(NSString *)kMRMediaRemoteNowPlayingInfoAlbum];

		playerArtwork.image = albumImage;
		nowPlayingViewArtwork.image = albumImage;
		titleLabel.text = titleStr;
		if (albumStr != nil) {
			artistLabel.text = [NSString stringWithFormat:@"%@ ─ %@", artistStr, albumStr];
		} else {
			artistLabel.text = artistStr;
		}

        MPMediaItem *currentSong = [[MPMusicPlayerController systemMusicPlayer] nowPlayingItem];
        NSString *titlePlayerController = [currentSong valueForProperty:MPMediaItemPropertyTitle];
        if ([titleStr isEqual:titlePlayerController]) {
            trackProgressView.scrubbingEnabled = TRUE;
        } else {
            trackProgressView.scrubbingEnabled = FALSE;
        }

		HBLogDebug(@"albumImage = %@ / titleStr = %@ / artistStr = %@ / albumStr = %@", albumImage, titleStr, artistStr, albumStr);
	});
}

%new
- (void)openNowPlayingView {
	if (nowPlayingView.alpha == 0.0) {
        [UIView animateWithDuration:0.3f animations:^{
            nowPlayingView.alpha = 1.0;
        }];
    } else {
        [UIView animateWithDuration:0.3f animations:^{
            nowPlayingView.alpha = 0.0;
        }];
    }
}

%new
- (void)verticalStartTimer {
    _timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(verticalUpdateScrubber) userInfo:nil repeats:YES];
}

%new
-(void)verticalUpdateScrubber {
    MRMediaRemoteGetNowPlayingInfo(dispatch_get_main_queue(), ^(CFDictionaryRef result) {
        CFAbsoluteTime MusicStarted = CFDateGetAbsoluteTime((CFDateRef)[(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoTimestamp]);
        NSTimeInterval timeIntervalifPause = (NSTimeInterval)[[(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoElapsedTime] doubleValue];
        NSTimeInterval duration = (NSTimeInterval)[[(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoDuration] doubleValue];
        NSTimeInterval nowSec = (CFAbsoluteTimeGetCurrent() - MusicStarted) + (timeIntervalifPause>1?timeIntervalifPause:0);
        NSTimeInterval currentPlayback = duration?(nowSec/duration):0;
		NSTimeInterval realCurrentPlayback = currentPlayback*duration;
        trackProgressView.currentTime = realCurrentPlayback;
        trackProgressView.totalDuration = (NSTimeInterval)[[(__bridge NSDictionary *)result objectForKey:(__bridge NSString *)kMRMediaRemoteNowPlayingInfoDuration] doubleValue];
    });
}

%new
- (void)progressView:(MPUChronologicalProgressView *)progressView didScrubToCurrentTime:(NSTimeInterval)time {
	HBLogDebug(@"didScrubToCurrentTime");
    MRMediaRemoteSetElapsedTime(time);
}

%new
- (void)playPauseButtonDidPress:(RSPlayPauseButton *)playPauseButton {
    MRMediaRemoteSendCommand(kMRTogglePlayPause, nil);

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), ^(Boolean isPlay) {
            if (!isPlay && wantsToPlay == TRUE) {
                MPMusicPlayerController *musicPlayer = [MPMusicPlayerController systemMusicPlayer];
                [musicPlayer play];
                [musicPlayer release];
            }
        });
    });

    MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_get_main_queue(), ^(Boolean isPlay) {
        if (!isPlay) {
            wantsToPlay = TRUE;
            if(_timer) {
                [_timer invalidate];
                _timer = nil;

            }
            [playPauseButton setPaused:TRUE animated:YES];
        } else {
            wantsToPlay = FALSE;
            if(_timer)
            {
                [_timer invalidate];
                 _timer = nil;
            }
            [playPauseButton setPaused:FALSE animated:YES];
            [self verticalStartTimer];
        }
    });
}

%end

%hook SBLockScreenNowPlayingPluginController
- (id)initWithLockScreenViewController:(id)arg1 mediaController:(id)arg2 {
    if (enabled) {
        arg2 = nil;
    }
    return %orig;
}
%end

%ctor {
    preferences = [HBPreferences preferencesForIdentifier:@"com.ziph0n.vertical"];
    [preferences registerBool:&enabled default:YES forKey:@"enabled"];
	[preferences registerInteger:&playerStyle default:1 forKey:@"playerStyle"];
	[preferences registerInteger:&playerWidth default:100 forKey:@"playerWidth"];
}
