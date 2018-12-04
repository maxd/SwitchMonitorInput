//
//  main.m
//  SwitchMonitorInput
//
//  Created by Maxim Dobryakov on 03/12/2018.
//  Copyright © 2018 Maxim Dobryakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "MonitorManager.h"

const Byte controlId = 0x60; // Input Source

void displayMonitorInputSource(MonitorManager *monitorManager, io_service_t monitor, NSString *monitorId);
void changeMonitorInputSource(MonitorManager *monitorManager, io_service_t monitor, NSString *monitorId, UInt16 value);

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        NSString *primaryMonitorLocation = @"IOService:/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/PEG0@1/IOPP/PEGP@0/NVDA,Display-C@2/NVDA/display0/AppleDisplay";
        NSString *secondaryMonitorLocation = @"IOService:/AppleACPIPlatformExpert/PCI0@0/AppleACPIPCI/PEG0@1/IOPP/PEGP@0/NVDA,Display-B@1/NVDA/display0/AppleDisplay";

        NSDictionary *primaryMonitorProfile = @{
            @"desktop": @16,
            @"laptop": @15,
        };

        NSDictionary *secondaryMonitorProfile = @{
            @"desktop": @18,
            @"laptop": @15,
        };
        

        MonitorManager *monitorManager = [MonitorManager new];

        io_service_t primaryMonitor = [monitorManager findMonitorByLocation:primaryMonitorLocation];
        io_service_t secondaryMonitor = [monitorManager findMonitorByLocation:secondaryMonitorLocation];

        if (argc == 1) {
            displayMonitorInputSource(monitorManager, primaryMonitor, @"Primary Monitor");
            displayMonitorInputSource(monitorManager, secondaryMonitor, @"Secondary Monitor");
        } else if (argc == 2) {
            NSString *profileId = [NSString stringWithUTF8String:argv[1]];

            changeMonitorInputSource(monitorManager, primaryMonitor, @"Primary Monitor", [primaryMonitorProfile[profileId] intValue]);
            changeMonitorInputSource(monitorManager, secondaryMonitor, @"Secondary Monitor", [secondaryMonitorProfile[profileId] intValue]);
        }
        
        IOObjectRelease(primaryMonitor);
        IOObjectRelease(secondaryMonitor);
    }
    return 0;
}

void displayMonitorInputSource(MonitorManager *monitorManager, io_service_t monitor, NSString *monitorId) {
    UInt16 maxValue;
    UInt16 currentValue;
    bool result = [monitorManager readValueOf:controlId forMonitor:monitor toCurrentValue:&currentValue toMaxValue:&maxValue];
    if (result) {
        NSLog(@"%@: Current Input Source: %d (max: %d)", monitorId, currentValue, maxValue);
    } else {
        NSLog(@"%@: Error!", monitorId);
        exit(1);
    }
}

void changeMonitorInputSource(MonitorManager *monitorManager, io_service_t monitor, NSString *monitorId, UInt16 value) {
    bool result = [monitorManager writeValueOf:controlId forMonitor:monitor fromValue:value];
    if (result) {
        NSLog(@"%@: Set Input Source: %d", monitorId, value);
    } else {
        NSLog(@"%@: Not Changed!", monitorId);
        exit(1);
    }
}
