//
//  MonitorManager.h
//  SwitchMonitorInput
//
//  Created by Maxim Dobryakov on 03/12/2018.
//  Copyright © 2018 Maxim Dobryakov. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <IOKit/i2c/IOI2CInterface.h>

NS_ASSUME_NONNULL_BEGIN

@interface MonitorManager : NSObject

- (io_service_t)findMonitorByLocation:(NSString *)location;

- (bool)readValueOf:(Byte)controlId forMonitor:(io_service_t)monitor toCurrentValue:(UInt16 *)currentValue toMaxValue:(UInt16 *)maxValue;
- (bool)writeValueOf:(Byte)controlId forMonitor:(io_service_t)monitor fromValue:(UInt16)value;
@end

NS_ASSUME_NONNULL_END
