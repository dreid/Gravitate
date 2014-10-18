//
//  Gravitate.m
//  Gravitate
//
//  Created by David Reid on 10/17/14.
//  Copyright (c) 2014 David Reid. All rights reserved.
//

#import <CommonCrypto/CommonDigest.h>
#import "Gravitate.h"

@implementation Gravitate

// This example action works with phone numbers.
- (NSString *)actionProperty
{
    return kABEmailProperty;
}

// Our menu title will look like Speak 555-1212
- (NSString *)titleForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    ABMultiValue *values = [person valueForProperty:[self actionProperty]];
    NSString *value = [values valueForIdentifier:identifier];

    if([self hasGravatar:value]) {
        return @"Set image from gravatar.";
    } else {
        return nil;
    }
}

// This method is called when the user selects your action. As above, this method
// is passed information about the data item rolled over.
- (void)performActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    ABMultiValue *values = [person valueForProperty:[self actionProperty]];
    NSString *value = [values valueForIdentifier:identifier];

    NSURLSession *session = [NSURLSession sharedSession];
    
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self gravatarURL:value]];
    
    NSURLSessionDataTask *task = [session
        dataTaskWithRequest:request
        completionHandler:^ (NSData *data, NSURLResponse *resp, NSError *error){
            ABAddressBook *ab = [ABAddressBook sharedAddressBook];
            ABRecord *record = [ab recordForUniqueId:[person uniqueId]];
            ABPerson *newPerson = (ABPerson *)record;
            NSLog(@"Response code:%ld.", [(NSHTTPURLResponse *)resp statusCode]);
            if([(NSHTTPURLResponse *)resp statusCode] == 200) {
                [newPerson setImageData:data];
                [ab save];
            }
        }];
    
    [task resume];
}

// Optional. Your action will always be enabled in the absence of this method. As
// above, this method is passed information about the data item rolled over.
- (BOOL)shouldEnableActionForPerson:(ABPerson *)person identifier:(NSString *)identifier
{
    return YES;
}

- (NSURL *)gravatarURL:(NSString *)email
{
    const char* email_char = [email UTF8String];
    unsigned char email_md5[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(email_char, (CC_LONG)strlen(email_char), email_md5);
    
    NSMutableString *email_hexdigest = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH*2];
    for(int i = 0; i<CC_MD5_DIGEST_LENGTH; i++) {
        [email_hexdigest appendFormat:@"%02x",email_md5[i]];
    }
    
    return [NSURL URLWithString:[NSString
                              stringWithFormat:@"https://www.gravatar.com/avatar/%@.jpg?s=2048&d=404",email_hexdigest]];
}

- (BOOL)hasGravatar:(NSString *)email
{
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block BOOL answer = NO;
    
    NSURLSession *session = [NSURLSession sharedSession];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self gravatarURL:email]];
    request.HTTPMethod = @"HEAD";
    
    NSURLSessionDataTask *task = [session dataTaskWithRequest:request
                                            completionHandler:^ (NSData *data, NSURLResponse *resp, NSError *error){

                                                if([(NSHTTPURLResponse *)resp statusCode] == 404) {
                                                    answer = NO;
                                                } else {
                                                    answer = YES;
                                                }

                                                dispatch_semaphore_signal(semaphore);
                                            }];
    
    [task resume];
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    
    return answer;
}

@end
