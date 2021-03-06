//
//  CouchDesignDocumentProxy.m
//  titouchdb
//
//  Created by Paul Mietz Egli on 4/5/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "CouchDesignDocumentProxy.h"
#import "CouchQueryProxy.h"
#import <TouchDB/TDDatabase+Insertion.h>
#import "ViewCompiler.h"
#import "TiMacroFixups.h"

@implementation CouchDesignDocumentProxy

bool validationChanged = NO;

@synthesize designDocument;

- (id)initWithCouchDesignDocument:(CouchDesignDocument *)ddoc {
    if (self = [super initWithCouchDocument:ddoc]) {
        self.designDocument = ddoc;
    }
    return self;
}

+ (CouchDesignDocumentProxy *)proxyWith:(CouchDesignDocument *)ddoc {
    return ddoc ? [[[CouchDesignDocumentProxy alloc] initWithCouchDesignDocument:ddoc] autorelease] : nil;
}

#pragma mark PROPERTIES

- (id)language {
    return self.designDocument.language;
}

- (void)setLanguage:(id)val {
    self.designDocument.language = val;
}

- (id)viewNames {
    return self.designDocument.viewNames;
}

- (id)validation {
    return self.designDocument.validation;
}

- (void)setValidation:(id)val {
    self.designDocument.validation = val;
    validationChanged = YES;
}

- (id)includeLocalSequence {
    return [NSNumber numberWithBool:self.designDocument.includeLocalSequence];
}

- (void)setIncludeLocalSequence:(id)val {
    self.designDocument.includeLocalSequence = [val boolValue];
}

- (id)changed {
    return [NSNumber numberWithBool:self.designDocument.changed];
}



#pragma mark METHODS

- (id)queryViewNamed:(id)args {
    NSString * name;
    ENSURE_ARG_AT_INDEX(name, args, 0, NSString)

    // only return a query if the view exists
    if ([self.designDocument mapFunctionOfViewNamed:name]) {
        return [CouchQueryProxy proxyWith:[self.designDocument queryViewNamed:name]];
    }
    else {
        return nil;
    }
}

- (id)isLanguageAvailable:(id)args {
    NSString * lang;
    ENSURE_ARG_AT_INDEX(lang, args, 0, NSString)
    
    return [NSNumber numberWithBool:[self.designDocument isLanguageAvailable:lang]];
}

- (id)mapFunctionOfViewNamed:(id)args {
    NSString * name;
    ENSURE_ARG_AT_INDEX(name, args, 0, NSString)
    return [self.designDocument mapFunctionOfViewNamed:name];
}

- (id)reduceFunctionOfViewNamed:(id)args {
    NSString * name;
    ENSURE_ARG_AT_INDEX(name, args, 0, NSString)
    return [self.designDocument reduceFunctionOfViewNamed:name];
}

- (void)defineView:(id)args {
    NSString * name;
    NSString * mapFunction;
    NSString * reduceFunction;
    
    ENSURE_ARG_AT_INDEX(name, args, 0, NSString)
    ENSURE_ARG_OR_NIL_AT_INDEX(mapFunction, args, 1, NSString)
    ENSURE_ARG_OR_NIL_AT_INDEX(reduceFunction, args, 2, NSString)
    
    [self.designDocument defineViewNamed:name map:mapFunction reduce:reduceFunction];
}

- (void)saveChanges:(id)args {
    RESTOperation * op = [self.designDocument saveChanges];
    if (![op wait]) {
        NSAssert(!op.error, @"Error calling saveChanges: %@", op.error);
    }
    
    if (validationChanged) {
        // add validation function to db
        CouchTouchDBServer * server = (CouchTouchDBServer *) self.designDocument.database.server;
        NSString * fnname = self.designDocument.relativePath;
        NSString * dbname = self.designDocument.database.relativePath;
        NSString * valfn = self.designDocument.validation;
        
        [server tellTDDatabaseNamed:dbname to:^(TDDatabase * db) {
            if (valfn) {
                TDValidationBlock compiled = [(ViewCompiler *)TDView.compiler compileValidationFunction:self.designDocument.validation language:@"javascript" database:db];
                [db defineValidation:fnname asBlock:compiled];
                NSLog(@"saved validation %@ function to db %@", fnname, dbname);
            }
            else {
                [db defineValidation:dbname asBlock:nil];
                NSLog(@"removed validation %@ function from db %@", fnname, dbname);
            }
        }];
        
        validationChanged = NO;
    }

}

@end
