// USBAnywhere project: oscarlosu-lab (SnakeFoxu) — https://github.com/oscarlosu-lab
// Copyright 2026 Denis Arnst (Sapd) — https://github.com/Sapd
// Licensed under GPL-3.0; see the repository LICENSE.
#import <Foundation/Foundation.h>
// Swift cannot catch Objective-C exceptions raised during asynchronous USB teardown.
BOOL USBGuard(void (^ _Nonnull operation)(void), NSError * _Nullable * _Nullable error);
