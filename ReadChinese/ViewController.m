//
//  ViewController.m
//  ReadChinese
//
//  Created by Ashen on 15/12/10.
//  Copyright © 2015年 Ashen. All rights reserved.
//

#import "ViewController.h"
#import "ASConvertor.h"
#import "ReactiveObjC/ReactiveObjC.h"

#define CHINESE_REGULAR_EXPRESSION       [NSRegularExpression regularExpressionWithPattern:@"\"[^\"]*[\\u4E00-\\u9FA5]+[^\"\\n]*?\"" options:NSRegularExpressionCaseInsensitive error:nil]
#define IS_LOG_CODE(line)                [line containsString:@"NSLog"] || [line containsString:@"GSLog"] || [line containsString:@"DebugLog"]
#define IS_SPECIAL_CODE(line)            [line containsString:@"MJRefreshDeprecated"] || [line containsString:@"MJExtensionDeprecated"] || [line containsString:@"MJExtensionAssertError"] || [line containsString:@"deprecated("] || [line containsString:@"__deprecated_msg("] || [line containsString:@"@discussion"] || [line containsString:@"#pragma mark"] || [line containsString:@"NSAssert("] || [line containsString:@"/**"]

@interface SearchResult : NSObject
@property (nonatomic, copy) NSString *filePath;
/**搜索结果 按长度倒序   没有去重*/
@property (nonatomic, strong) NSArray <NSTextCheckingResult *> *arrayTextCheckingResult;
@end
@implementation SearchResult

+ (SearchResult *)resultWithFilePath:(NSString *)filePath arrayTextCheckingResult:(NSArray <NSTextCheckingResult *> *)arrayTextCheckingResult
{
    SearchResult *result = [[SearchResult alloc] init];
    result.filePath = filePath;
    
    arrayTextCheckingResult = [arrayTextCheckingResult sortedArrayUsingComparator:^NSComparisonResult(NSTextCheckingResult *  _Nonnull obj1, NSTextCheckingResult *  _Nonnull obj2) {
        return obj1.range.length > obj2.range.length ? NSOrderedAscending : NSOrderedDescending;
    }];

    result.arrayTextCheckingResult = arrayTextCheckingResult;
    return result;
}

@end

@interface ParseLineResult : NSObject
@property (nonatomic, copy) NSString *code;
@property (nonatomic, copy) NSString *remark;

@property (nonatomic, assign) BOOL codeContainsChinese;
@property (nonatomic, assign) BOOL remarkContainsChinese;
@end

@implementation ParseLineResult
+ (instancetype)resultWithLineCode:(NSString *)lineCode
{
    ParseLineResult *result = [[ParseLineResult alloc] init];

    NSMutableArray *aySubCodes = [[lineCode componentsSeparatedByString:@"//"] mutableCopy];
    result.code = aySubCodes.firstObject;
    
    [aySubCodes removeObject:result.code];
    
    result.remark = [aySubCodes componentsJoinedByString:@"//"];
    
    result.codeContainsChinese = [CHINESE_REGULAR_EXPRESSION matchesInString:result.code options:0 range:NSMakeRange(0, result.code.length)].count > 0;
    
    result.remarkContainsChinese = [CHINESE_REGULAR_EXPRESSION matchesInString:result.remark options:0 range:NSMakeRange(0, result.remark.length)].count > 0;
    
    return result;
}
@end



@interface LocalizedSringsModel : NSObject
@property (nonatomic, copy) NSString *path;
@property (nonatomic, strong) NSArray <NSString *> *ayKeys;
@property (nonatomic, strong) NSArray <NSString *> *ayValues;
@property (nonatomic, strong) NSArray <NSString *> *aySameKeys;
@end

@implementation LocalizedSringsModel

@end


@interface ViewController()

@property (weak) IBOutlet NSTextField *txtShowPath;
@property (weak) IBOutlet NSTextField *txtShowOutPath;
@property (weak) IBOutlet NSScrollView *txtShowChinese;
@property (weak) IBOutlet NSButton *deleteInOneFile;
@property (weak) IBOutlet NSButton *deleteInAllFiles;
@property (weak) IBOutlet NSButton *tradition;

@property (nonatomic, strong)  NSTextView *txtView;


@property (nonatomic, strong) NSMutableArray <SearchResult *> *arraySearchResult;
@property (nonatomic, strong) NSMutableArray <LocalizedSringsModel *> *arrayLocalizedStringModels;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.txtShowPath.editable = NO;
    self.txtShowOutPath.editable = NO;
    
    
    [self exportAction:nil];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
}

#pragma mark - action
- (IBAction)deleteInAllFiles:(NSButton *)sender {
    self.deleteInOneFile.state = 0;
}

- (IBAction)deleteInOneFile:(NSButton *)sender {
    self.deleteInAllFiles.state = 0;
}


- (IBAction)OpenFile:(NSButton *)sender {
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
    [oPanel setCanChooseDirectories:YES];
    [oPanel setCanChooseFiles:NO];
    if ([oPanel runModal] == NSModalResponseOK) {
        NSString *path = [[[[[oPanel URLs] objectAtIndex:0] absoluteString] componentsSeparatedByString:@":"] lastObject];
        path = [[path stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] stringByExpandingTildeInPath];
        if (sender.tag == 100) {
            self.txtShowPath.placeholderString = path;
        } else {
            self.txtShowOutPath.placeholderString = [path stringByAppendingPathComponent:@"chinese.txt"];
        }
    }
}

- (IBAction)exportAction:(id)sender {
    self.deleteInAllFiles.state = 1;
    self.arraySearchResult = self.arraySearchResult ?: [NSMutableArray array];
    [self.arraySearchResult removeAllObjects];
    
//    [self readFiles:self.txtShowPath.placeholderString];
//    [self localizedStringReplacedWithFolderPath:self.txtShowPath.placeholderString];
//    [self analysisLocolizedStringsWithFolder:self.txtShowPath.placeholderString];
}

#pragma mark - Method
- (void)showTxt:(NSMutableString *)txt {
    self.txtView.string = txt;
    self.txtShowChinese.documentView = _txtView;
}

/**读取指定路径中的所有中文*/
- (void)readFiles:(NSString *)str
{
    if (self.txtShowPath.placeholderString.length == 0 || self.txtShowOutPath.placeholderString.length == 0) {
        [self showTxt:[@"亲，选择路径没？" mutableCopy]];
        return;
    }
    [self showTxt:[@"开始导出" mutableCopy]];
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *home = [str stringByExpandingTildeInPath];
    NSMutableString   *dataMstr = [NSMutableString string];
    NSMutableArray    *dataMSet = [NSMutableArray array];

    NSDirectoryEnumerator *direnum = [manager enumeratorAtPath:home];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:42];

    NSString *filename ;
    NSArray *extension = @[@"m", @"h", @"storyboard", @"xib", @"swift"];
    while (filename = [direnum nextObject]) {
        for (NSString *ext in extension) {
            if ([[filename pathExtension] isEqualToString:ext]) {
                [files addObject: filename];
            }
        }
    }
    NSEnumerator *fileenum;
    fileenum = [files objectEnumerator];
    NSInteger chineseCount = 0;
    while (filename = [fileenum nextObject]) {

        NSMutableArray *dataInOneFile = [NSMutableArray array];

        NSString *str=[NSString stringWithContentsOfFile:[NSString stringWithFormat:@"%@/%@", home, filename] encoding:NSUTF8StringEncoding error:nil];

        NSRegularExpression *regular = [NSRegularExpression regularExpressionWithPattern:@"\"[^\"]*[\\u4E00-\\u9FA5]+[^\"\\n]*?\"" options:NSRegularExpressionCaseInsensitive error:nil];

        NSArray *matches = [regular matchesInString:str
                                            options:0
                                              range:NSMakeRange(0, str.length)];


        NSString *newFileName =  [NSString stringWithFormat:@"\n/*\n%@\n*/", [[filename componentsSeparatedByString:@"/"] lastObject]];
        BOOL isHasFileName = NO;
        BOOL isHasChineseInFile = NO;
        for (NSTextCheckingResult *match in matches) {
            NSRange range = [match range];
            NSString *mStr = [str substringWithRange:range];
            
            NSString *strLine = [self getLineStringWithRange:range fromString:str];
            ParseLineResult *result = [ParseLineResult resultWithLineCode:strLine];
            if (!result.codeContainsChinese || IS_LOG_CODE(strLine) || IS_SPECIAL_CODE(strLine)) { //过滤特殊串
                continue;
            }

            
            if (!isHasFileName) {
                [dataMSet addObject:newFileName];
            }

            NSRange isOnlyAt = NSMakeRange(0, 0);
            mStr = [mStr stringByReplacingCharactersInRange:isOnlyAt withString:@""];
            isHasFileName = YES;

            if (self.deleteInOneFile.state) {
                if ([dataInOneFile containsObject:mStr]) { //除去本文件中重复出现的字符串
                    continue;
                }
                [dataInOneFile addObject:mStr];
            }

            if (self.deleteInAllFiles.state) {
                if ([dataMSet containsObject:mStr]) {  //除去所有文件中重复出现的字符串
                    continue;
                }
            }
            chineseCount++;
            [dataMSet addObject:mStr];
            isHasChineseInFile = YES;
        }
        if (!isHasChineseInFile) {
            [dataMSet removeObject:newFileName];
        }
    }

    for (NSString *txt in dataMSet) {
        if ([txt containsString:@"/*"] && [txt containsString:@"*/"]) {
            [dataMstr appendString:txt];
            [dataMstr appendString:@"\n"];
            continue;
        }
        [dataMstr appendString:[[txt stringByAppendingString:@" = "] stringByAppendingString:                self.tradition.state ? [[ASConvertor getInstance] s2t:txt] : txt]];
        [dataMstr appendString:@";"];
        [dataMstr appendString:@"\n"];
    }
    [dataMstr writeToFile:self.txtShowOutPath.placeholderString atomically:YES encoding:NSUTF8StringEncoding error:nil];

    NSMutableString *finalStr = [NSMutableString stringWithFormat:@"\n共有 %ld 个中文字符串\n", chineseCount];
    [finalStr appendString:dataMstr];
    [self showTxt:finalStr];
}

/**递归指定路径下面所有的指定后缀文件*/
- (void)enumeratorFolderFilesWithFolderPath:(NSString *)folderPlath extensions:(NSArray <NSString *> *)extensions objectsUsingBlock:(void (^)(NSString *filePath, BOOL *stop))objectsUsingBlock;
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSDirectoryEnumerator *direnum = [manager enumeratorAtPath:folderPlath];
    NSMutableArray *files = [NSMutableArray arrayWithCapacity:42];
    
    NSString *filename ;
    while (filename = [direnum nextObject]) {
        for (NSString *ext in extensions) {
            if ([[filename pathExtension] isEqualToString:ext]) {
                [files addObject: filename];
            }
        }
    }
    
    BOOL stop = NO;
    NSEnumerator *fileenum;
    fileenum = [files objectEnumerator];
    while (filename = [fileenum nextObject]) {
        if (stop) {
            break;
        }
        !objectsUsingBlock ?: objectsUsingBlock([NSString stringWithFormat:@"%@/%@", folderPlath, filename], &stop);
    }
}

- (BOOL)filterFilePath:(NSString *)filePath
{
    //排除的文件
    BOOL filterFilePath =
    [filePath.lastPathComponent hasPrefix:@"MQ"]
    || [filePath.lastPathComponent hasPrefix:@"RC"]
    || [filePath.lastPathComponent hasPrefix:@"MJ"]
    
    || [filePath containsString:@"JPush"]
    || [filePath containsString:@"MJExtension"]
    || [filePath containsString:@"TZImagePickerController"]
    || [filePath containsString:@"AAChartKitLib"]
    || [filePath containsString:@"RealTimeLocationViewController"]
    || [filePath containsString:@"RealTimeLocationStatusView"]
    
    || [filePath containsString:@"Pods"]
    ;
    return filterFilePath;
}

/**获取指定位置的整行文本*/
- (NSString *)getLineStringWithRange:(NSRange)range fromString:(NSString *)string
{
    NSString *strChecking = [string substringWithRange:range];
    NSString *strPrevious = [[string substringWithRange:NSMakeRange(0, range.location)] componentsSeparatedByString:@"\n"].lastObject;
    NSString *strNext = [[string substringWithRange:NSMakeRange(range.location + range.length, string.length - range.location - range.length)] componentsSeparatedByString:@"\n"].firstObject;
    
    return [NSString stringWithFormat:@"%@%@%@", strPrevious, strChecking, strNext]; //获取行数据
}

//替换文件中的中文(中文字符串常量 静态变量)为本地化代码
//(有Bug, 替换文件内容按查找文本的长度倒序)
- (void)localizedStringReplacedWithFolderPath:(NSString *)folderPath;
{
    BOOL isBackUp = true;
    NSString *strBackupExtension = @"J_backup_J"; //备份时, 把所有文件都添加统一后缀
    NSArray *aySearchFileExtensions = @[@"h", @"m"];
    NSArray *extensions = isBackUp ? aySearchFileExtensions : @[ strBackupExtension ];
    
    //查找文本的正则  有双引号且内部带中文的
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern:@"\"[^\"]*[\\u4E00-\\u9FA5]+[^\"\\n]*?\"" options:NSRegularExpressionCaseInsensitive error:nil];
    
    NSMutableArray *dataInOneFile = [NSMutableArray array];
    NSMutableArray *dataMSet = [NSMutableArray array];
    
    [self enumeratorFolderFilesWithFolderPath:[folderPath stringByExpandingTildeInPath] extensions:extensions objectsUsingBlock:^(NSString *filePath, BOOL *stop) {
        
        NSString *str = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
        
        NSArray *matches = [regularExpression matchesInString:str options:0 range:NSMakeRange(0, str.length)];
        
        NSString *newFileName =  [NSString stringWithFormat:@"\n/*\n%@\n*/", [[filePath.lastPathComponent componentsSeparatedByString:@"/"] lastObject]];
        BOOL isHasFileName = NO;
        BOOL isHasChineseInFile = NO;
        for (NSTextCheckingResult *match in matches) {
            if (!isHasFileName) {
                [dataMSet addObject:newFileName];
            }
            NSRange range = [match range];
            NSString *mStr = [str substringWithRange:range];
            NSRange isOnlyAt = NSMakeRange(0, 0);
            mStr = [mStr stringByReplacingCharactersInRange:isOnlyAt withString:@""];
            isHasFileName = YES;
            
            if (self.deleteInOneFile.state) {
                if ([dataInOneFile containsObject:mStr]) { //除去本文件中重复出现的字符串
                    continue;
                }
                [dataInOneFile addObject:mStr];
            }
            
            if (self.deleteInAllFiles.state) {
                if ([dataMSet containsObject:mStr]) {  //除去所有文件中重复出现的字符串
                    continue;
                }
            }
            [dataMSet addObject:mStr];
            isHasChineseInFile = YES;
        }
        if (!isHasChineseInFile) {
            [dataMSet removeObject:newFileName];
        }
        
        [self.arraySearchResult addObject:[SearchResult resultWithFilePath:filePath arrayTextCheckingResult:matches]];
    }];
    
    
    
    NSString *strReplaceLocalized = @"[AppRuntimeConfig localizedStringWithKey:%@]";
    NSMutableSet *setConstString = [NSMutableSet set];  //记录查找到的字符串常量/静态变量
    
    [self.arraySearchResult enumerateObjectsUsingBlock:^(SearchResult * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (isBackUp) { //备份代码
            NSString *strBackUpPath = [obj.filePath stringByAppendingFormat:@".%@", strBackupExtension];
            if ([[NSFileManager defaultManager] fileExistsAtPath:strBackUpPath]) {
                [[NSFileManager defaultManager] removeItemAtPath:strBackUpPath error:nil];
            };
            [[NSFileManager defaultManager] copyItemAtPath:obj.filePath toPath:strBackUpPath error:nil];
        }else {
            
            if (obj.arrayTextCheckingResult.count > 1 && ![self filterFilePath:obj.filePath]) {
                
                if ([extensions containsObject:obj.filePath.pathExtension]) {
                    NSString *strOld = [NSString stringWithContentsOfFile:obj.filePath encoding:NSUTF8StringEncoding error:nil];
                    __block NSString *strNew = [strOld mutableCopy];
                    __block BOOL isEdit = NO;
                    
                    [strOld enumerateLinesUsingBlock:^(NSString * _Nonnull line, BOOL * _Nonnull stop) { //逐行替换
                        ParseLineResult *parseLineResult = [ParseLineResult resultWithLineCode:line];
                        //是否为字符串常量
                        BOOL isConstString = [line containsString:@"const"] && [line containsString:@"NSString"] && [line containsString:@"="] && parseLineResult.codeContainsChinese;
                        //是否为字符串静态变量
                        BOOL isStaticString = [line containsString:@"static"] && [line containsString:@"NSString"] && [line containsString:@"="] && parseLineResult.codeContainsChinese;
                        //是否为Log日志
                        BOOL isLogString = IS_LOG_CODE(line);
                        //指定代码关键字过滤
                        BOOL isSpecialCode = IS_SPECIAL_CODE(line);
                        
                        
                        __block NSString *strOldLine = [line mutableCopy];
                        NSMutableSet *setReplacedCheckings = [NSMutableSet set]; //记录替换过的串, 用于后续排除相同的
                        if (!isLogString && !isConstString && !isStaticString && !isSpecialCode && parseLineResult.codeContainsChinese) {  //行过滤条件
                            
                            [obj.arrayTextCheckingResult enumerateObjectsUsingBlock:^(NSTextCheckingResult * _Nonnull result, NSUInteger idx, BOOL * _Nonnull stop) {
                                NSString *strChecking = [strOld substringWithRange:result.range];
                                NSString *strPreviousChar = [strOld substringWithRange:NSMakeRange(result.range.location - 1, 1)];
                                NSString *strLine = [self getLineStringWithRange:result.range fromString:strOld]; //搜索结果的行数据
                                
                                if ([strPreviousChar isEqualToString:@"@"]) { //如果前一位是@符号, 包含它一起替换
                                    strChecking = [strOld substringWithRange:NSMakeRange(result.range.location - 1, result.range.length + 1)];
                                }
                                
                                
                                NSString *strReplacedChecking = nil;
                                NSString *strNewLine = nil;
                                if ([strOldLine containsString:strChecking] && [ParseLineResult resultWithLineCode:strLine].codeContainsChinese && ![setReplacedCheckings containsObject:strChecking]) {
                                    isEdit = YES;
                                    [setReplacedCheckings addObject:strChecking];
                                    strReplacedChecking = [NSString stringWithFormat: strReplaceLocalized, strChecking]; //生成替换后的本地化代码
                                    
                                    strNewLine = [strOldLine stringByReplacingOccurrencesOfString:strChecking withString:strReplacedChecking]; //替换旧的行中的文本
                                    strNew = [strNew stringByReplacingOccurrencesOfString:strOldLine withString:strNewLine]; //替换整个旧的行
                                    strOldLine = strNewLine; //此处重新赋值是因为 一行可能有多串中文的情况;
                                }
                                
                                if (strReplacedChecking) {
                                    NSLog(@"\nchecking string:%@\nmodify checking string:%@\nold line string:%@\nnew line string:%@\nfile path:%@\n---------------------------------------------------------", strChecking, strReplacedChecking, line, strNewLine, obj.filePath);
                                }
                            }];
                        }
                        
                        isConstString ? [setConstString addObject:strOldLine] : nil;
                    }];
                    
                    if (isEdit) {
                        NSString *path = [obj.filePath stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@", strBackupExtension] withString:@""];
                        [strNew writeToFile:path atomically:NO encoding:NSUTF8StringEncoding error:nil];
                    }
                }
            }
        }
    }];
    
    if (!isBackUp) {
        //替换字符串常量
        [self enumeratorFolderFilesWithFolderPath:[folderPath stringByExpandingTildeInPath] extensions:aySearchFileExtensions objectsUsingBlock:^(NSString *filePath, BOOL *stop) {
            
            if (![self filterFilePath:filePath]) {
                __block NSString *strOld = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
                __block BOOL isEdit = NO;
                
                [setConstString enumerateObjectsUsingBlock:^(id  _Nonnull obj, BOOL * _Nonnull stop) {
                    NSString *strConst = [obj componentsSeparatedByString:@"="].firstObject;
                    strConst = [strConst stringByReplacingOccurrencesOfString:@"NSString" withString:@""];
                    strConst = [strConst stringByReplacingOccurrencesOfString:@"const" withString:@""];
                    strConst = [strConst stringByReplacingOccurrencesOfString:@"*" withString:@""];
                    strConst = [strConst stringByReplacingOccurrencesOfString:@" " withString:@""];
                    
                    NSArray *matches = [[NSRegularExpression regularExpressionWithPattern:[NSString stringWithFormat:@"%@", strConst] options:0 error:nil] matchesInString:strOld options:0 range:NSMakeRange(0, strOld.length)];
                    
                    NSMutableDictionary *dictSpecialCode = [NSMutableDictionary dictionary];
                    __block NSString *strNew = [strOld mutableCopy];  //用于字符串替换, strOld仅用于查找(直接替换strOld会导致c之前的metche有问题)
                    
                    for (NSTextCheckingResult *matche in matches) {
                        isEdit = YES;
                        
                        NSString *strLine = [self getLineStringWithRange:matche.range fromString:strOld];
                        
                        BOOL isSpecialLine = [strLine containsString:obj] || ([strLine containsString:@"const"] && [strLine containsString:@"extern"]);
                        
                        if (isSpecialLine) { //不需要替换的串, 自用占位串先行x替换, 后面再还原回来
                            NSString *strNewLine = [NSString stringWithFormat:@"__________特殊串替换(%ld)_______", matche.range.location];
                            [dictSpecialCode setObject:strLine forKey:strNewLine];
                            strNew = [strNew stringByReplacingOccurrencesOfString:strLine withString:strNewLine];
                        }
                    }
                    
                    NSString *strReplacedChecking = [NSString stringWithFormat: strReplaceLocalized, strConst];
                    strNew = [strNew stringByReplacingOccurrencesOfString:strConst withString:strReplacedChecking];
                    
                    [dictSpecialCode enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
                        strNew = [strNew stringByReplacingOccurrencesOfString:key withString:obj]; //还原替换的串
                    }];
                    
                    strOld = strNew;
                }];
                
                if (isEdit) {
                    [strOld writeToFile:filePath atomically:NO encoding:NSUTF8StringEncoding error:nil];
                    NSLog(@"替换常量操作:%@", filePath);
                }
            }
        }];
    }
    NSLog(@"执行结束>>>>>>");
}

/**替换第一个双引号之前的字符 和 最后一个双引号之后的字符*/
- (NSString *)recursionReplaceUnValidCharWithString:(NSString *)string
{
    if (string.length > 0) {
        NSString *strFirstChar = [string substringToIndex:1];
        NSString *strLastChar = [string substringFromIndex:string.length - 1];
        
        if (![strFirstChar isEqualToString:@"\""]) {
            [self recursionReplaceUnValidCharWithString:[string substringFromIndex:1]];
        }
        else if (![strLastChar isEqualToString:@"\""]) {
            [self recursionReplaceUnValidCharWithString:[string substringToIndex:string.length - 1]];
        }
    }
    return string;
}

/**所有的srings文件, 找出不同的key, 及缺失的key*/
- (void)analysisLocolizedStringsWithFolder:(NSString *)folderPath
{
    self.arrayLocalizedStringModels = self.arrayLocalizedStringModels ?: [NSMutableArray array];
    
    [self enumeratorFolderFilesWithFolderPath:folderPath extensions:@[@"strings"] objectsUsingBlock:^(NSString *filePath, BOOL *stop) {
        
        if ([filePath.lastPathComponent isEqualToString:@"Localizable.strings"] && ![filePath containsString:@".bundle"]) {
            NSString *str = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
            
            NSMutableArray *ayKeys = [NSMutableArray array];
            NSMutableArray *ayValues = [NSMutableArray array];
            NSMutableArray *aySameKeys = [NSMutableArray array];
            
            NSArray *ay = [[str componentsSeparatedByString:@"\n"].rac_sequence filter:^BOOL(id  _Nullable value) {
                return [value containsString:@"="] && [value containsString:@"\""];
            }].array;
            
            [ay enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSArray *ay = [obj componentsSeparatedByString:@"="];
                NSString *key = [self recursionReplaceUnValidCharWithString:ay.firstObject];
                NSString *value = [self recursionReplaceUnValidCharWithString:ay.lastObject];
                
                if ([ayKeys containsObject:key]) { //存储已存在的key
                    [aySameKeys addObject:key];
                }
                
                [ayKeys addObject:key];
                [ayValues addObject:value];
            }];
            
            LocalizedSringsModel *localizedSringsModel = [[LocalizedSringsModel alloc] init];
            localizedSringsModel.path = filePath;
            localizedSringsModel.ayKeys = ayKeys;
            localizedSringsModel.aySameKeys = aySameKeys;
            localizedSringsModel.ayValues = ayValues;
            
            [self.arrayLocalizedStringModels addObject:localizedSringsModel];
        }
    }];
    
    
    NSSet *setAyKeys = [NSSet setWithArray:[self.arrayLocalizedStringModels.rac_sequence flattenMap:^__kindof RACSequence * _Nullable(LocalizedSringsModel * _Nullable value) {
        return value.ayKeys.rac_sequence;
    }].array];
    
    
    NSMutableString *strLog = [NSMutableString string];
    [self.arrayLocalizedStringModels enumerateObjectsUsingBlock:^(LocalizedSringsModel * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        NSArray *ayUnContainsKeys = [setAyKeys.rac_sequence filter:^BOOL(id  _Nullable value) {
            return ![obj.ayKeys containsObject:value];
        }].array;
        if (obj.aySameKeys.count > 0) {
            [strLog appendFormat:@">>>>>>>>>%@中存在相同的keys:\n%@\n\n", obj.path, [obj.aySameKeys componentsJoinedByString:@"\n"]];
        }
        [strLog appendFormat:@"--------整合所有的文件得到缺失的keys, 请检查文件----%@\n%@\n\n", obj.path, [ayUnContainsKeys componentsJoinedByString:@"\n"]];
    }];
    NSLog(@"analysisLocolizedStringsLog:\n\n%@", strLog);
}

#pragma mark - getter / setter
- (NSTextView *)txtView {
    if (_txtView) {
        return _txtView;
    }
    _txtView = [[NSTextView alloc]initWithFrame:CGRectMake(0, 0, 335, 190)];
    [_txtView setMinSize:NSMakeSize(0.0, 190)];
    [_txtView setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
    [_txtView setVerticallyResizable:YES];
    [_txtView setHorizontallyResizable:NO];
    [_txtView setAutoresizingMask:NSViewWidthSizable];
    [[_txtView textContainer]setContainerSize:NSMakeSize(335,FLT_MAX)];
    [[_txtView textContainer]setWidthTracksTextView:YES];
    [_txtView setFont:[NSFont fontWithName:@"Helvetica" size:12.0]];
    [_txtView setEditable:NO];
    return _txtView;
}



@end
