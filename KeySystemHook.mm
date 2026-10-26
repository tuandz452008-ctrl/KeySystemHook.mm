// KeySystemHook.mm - Tích hợp Key System kiểm tra qua API server
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#include <string>

// Hàm gửi request kiểm tra key lên server http://tqtdev.2bd.net/check_key.com
std::string checkKeyOnServer(const std::string& key) {
    NSString *urlString = [NSString stringWithFormat:@"http://tqtdev.2bd.net/check_key.com?key=%s", key.c_str()];
    NSURL *url = [NSURL URLWithString:[urlString stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]]];
    if (!url) return "error";

    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data) return "error";

    NSString *response = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!response) return "error";

    return std::string([response UTF8String]);
}

// Hiển thị hộp thoại nhập Key trên màn hình iOS
void showKeyInputPopup() {
    dispatch_async(dispatch_get_main_query(), ^{
        UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
        UIViewController *rootVC = keyWindow.rootViewController;
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Kích hoạt bản quyền" 
                                                                        message:@"Vui lòng nhập Key để tiếp tục sử dụng:" 
                                                                 preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            textField.placeholder = @"Nhập Key tại đây...";
            textField.secureTextEntry = NO;
        }];
        
        UIAlertAction *submitAction = [UIAlertAction actionWithTitle:@"Xác thực" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            UITextField *textField = alert.textFields.firstObject;
            NSString *enteredKey = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            
            if (enteredKey.length > 0) {
                std::string keyStd = [enteredKey UTF8String];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    std::string res = checkKeyOnServer(keyStd);
                    
                    dispatch_async(dispatch_get_main_query(), ^{
                        if (res.find("success") != std::string::npos || res.find("true") != std::string::npos) {
                            [[NSUserDefaults standardUserDefaults] setObject:enteredKey forKey:@"SavedLicenseKey"];
                            [[NSUserDefaults standardUserDefaults] synchronize];
                            
                            UIAlertController *successAlert = [UIAlertController alertControllerWithTitle:@"Thành công" message:@"Kích hoạt bản quyền thành công!" preferredStyle:UIAlertControllerStyleAlert];
                            [successAlert addAction:[UIAlertAction actionWithTitle:@"Vào game" style:UIAlertActionStyleDefault handler:nil]];
                            [rootVC presentViewController:successAlert animated:YES completion:nil];
                        } else {
                            UIAlertController *errorAlert = [UIAlertController alertControllerWithTitle:@"Thất bại" message:@"Key không hợp lệ hoặc đã hết hạn!" preferredStyle:UIAlertControllerStyleAlert];
                            [errorAlert addAction:[UIAlertAction actionWithTitle:@"Thử lại" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
                                showKeyInputPopup();
                            }]];
                            [rootVC presentViewController:errorAlert animated:YES completion:nil];
                        }
                    });
                });
            } else {
                showKeyInputPopup();
            }
        }];
        
        [alert addAction:submitAction];
        [rootVC presentViewController:alert animated:YES completion:nil];
    });
}

__attribute__((constructor)) void initDylib() {
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidFinishLaunchingNotification 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        
        NSString *savedKey = [[NSUserDefaults standardUserDefaults] stringForKey:@"SavedLicenseKey"];
        if (!savedKey) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_query(), ^{
                showKeyInputPopup();
            });
        }
    });
}
