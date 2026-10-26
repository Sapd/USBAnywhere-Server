// USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
// Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
// Licensed under GPL-3.0; see the repository LICENSE.
#import "ExceptionGuard.h"
BOOL USBGuard(void (^operation)(void), NSError **error) {
    @try { operation(); return YES; }
    @catch (NSException *exception) {
        if (error) *error = [NSError errorWithDomain:@"USBAnywhere.Exception" code:1
            userInfo:@{NSLocalizedDescriptionKey:exception.reason ?: exception.name}];
        return NO;
    }
}
