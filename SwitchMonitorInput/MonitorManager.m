//
//  MonitorManager.m
//  SwitchMonitorInput
//
//  Created by Maxim Dobryakov on 03/12/2018.
//  Copyright © 2018 Maxim Dobryakov. All rights reserved.
//

#import "MonitorManager.h"

@implementation MonitorManager

const Byte sendAddress = 0x6E;
const Byte replayAddress = 0x6F;

const UInt64 kReplyDelay = 60;

- (io_service_t)findMonitorByLocation: (NSString *)expectedLocation {
    kern_return_t err;
    
    io_iterator_t iter;
    err = IOServiceGetMatchingServices(kIOMasterPortDefault, IOServiceMatching(IOFRAMEBUFFER_CONFORMSTO), &iter);
    if (err != KERN_SUCCESS) {
        [NSException raise: @"Fatal Error" format: @"IOServiceGetMatchingServices error: %d", err];
    }
    
    @try {
        io_service_t service;
        while ((service = IOIteratorNext(iter)) != MACH_PORT_NULL) {
            CFDictionaryRef info = IODisplayCreateInfoDictionary(service, kIODisplayMatchingInfo);
            
            NSString *location = (__bridge NSString *)CFDictionaryGetValue(info, CFSTR(kIODisplayLocationKey));
            
            CFRelease(info);
            
            if ([location isEqualToString:expectedLocation]) {
                return service;
            }
            
            IOObjectRelease(service);
        }
    }
    @finally {
        IOObjectRelease(iter);
    }
    
    return MACH_PORT_NULL;
}

- (void)sendRequest:(IOI2CRequest *)request toMonitor: (io_service_t)monitor {
    IOReturn err;
    
    IOItemCount busCount;
    err = IOFBGetI2CInterfaceCount(monitor, &busCount);
    
    if (err != kIOReturnSuccess) {
        [NSException raise: @"Fatal Error" format: @"IOFBGetI2CInterfaceCount error: %d", err];
    }
    
    for (IOOptionBits busIndex = 0; busIndex < busCount; busIndex++) {
        io_service_t interface;
        err = IOFBCopyI2CInterfaceForBus(monitor, busIndex, &interface);

        if (err != kIOReturnSuccess) {
            [NSException raise: @"Fatal Error" format: @"IOFBCopyI2CInterfaceForBus error: %d", err];
        }
        
        IOI2CConnectRef connect;
        err = IOI2CInterfaceOpen(interface, kNilOptions, &connect);
        if (err != kIOReturnSuccess) {
            [NSException raise: @"Fatal Error" format: @"IOI2CInterfaceOpen error: %d", err];
        }
        
        err = IOI2CSendRequest(connect, kNilOptions, request);
        if (err != kIOReturnSuccess) {
            [NSException raise: @"Fatal Error" format: @"IOI2CSendRequest error: %d", err];
        }
        
        err = IOI2CInterfaceClose(connect, kNilOptions);
        if (err != kIOReturnSuccess) {
            [NSException raise: @"Fatal Error" format: @"IOI2CInterfaceClose error: %d", err];
        }
        
        IOObjectRelease(interface);
    }
}

- (bool)readValueOf:(Byte)controlId forMonitor:(io_service_t)monitor toCurrentValue:(UInt16 *)currentValue toMaxValue:(UInt16 *)maxValue {
    Byte sendData[5] = {
        sendAddress,
        0x80 /* set bit for enable Control/Status protocol type */ | 2 /* command length, next 2 bytes */,
        0x01 /* read command */,
        controlId,
        sendData[0] ^ sendData[1] ^ sendData[2] ^ sendData[3]
    };
    
    Byte replyData[11] = {};
    
    IOI2CRequest request;
    bzero(&request, sizeof(request));
    
    request.sendAddress = sendAddress;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t) sendData;
    request.sendBytes = sizeof(sendData);
    
    request.replyTransactionType = kIOI2CSimpleTransactionType;
    request.replyAddress = replayAddress;
    request.replyBuffer = (vm_address_t) replyData;
    request.replyBytes = sizeof(replyData);
    
    request.minReplyDelay = 60;
    
    [self sendRequest:&request toMonitor:monitor];
    
    bool result = true;
    result &= replyData[0] == sendAddress;
    result &= replyData[2] == 0x2; /* read reply command */
    result &= replyData[4] == controlId;
    
    Byte replyCheckSum = 0x50 ^ replyData[0] ^ replyData[1] ^ replyData[2] ^ replyData[3] ^ replyData[4] ^ replyData[5] ^ replyData[6] ^ replyData[7] ^ replyData[8] ^ replyData[9];
    
    result &= replyData[10] == replyCheckSum;

    if (result) {
        *maxValue = 256 * replyData[6] + replyData[7];
        *currentValue = 256 * replyData[8] + replyData[9];
    }
    
    return result;
}

- (bool)writeValueOf:(Byte)controlId forMonitor:(io_service_t)monitor fromValue:(UInt16)value {
    Byte sendData[7] = {
        sendAddress,
        0x80 /* set bit for enable Control/Status protocol type */ | 4 /* command length, next 4 bytes */,
        0x03 /* read command */,
        controlId,
        value >> 8, /* high value byte */
        value & 0xFF, /* low value byte */
        sendData[0] ^ sendData[1] ^ sendData[2] ^ sendData[3] ^ sendData[4] ^ sendData[5]
    };
    
    IOI2CRequest request;
    bzero(&request, sizeof(request));
    
    request.sendAddress = sendAddress;
    request.sendTransactionType = kIOI2CSimpleTransactionType;
    request.sendBuffer = (vm_address_t) sendData;
    request.sendBytes = sizeof(sendData);
    
    request.minReplyDelay = kReplyDelay;
    
    [self sendRequest:&request toMonitor:monitor];
    
    return true;
}

@end
