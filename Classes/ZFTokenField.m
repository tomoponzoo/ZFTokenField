//
//  ZFTokenField.m
//  ZFTokenField
//
//  Created by Amornchai Kanokpullwad on 10/11/2014.
//  Copyright (c) 2014 Amornchai Kanokpullwad. All rights reserved.
//

#import "ZFTokenField.h"

@interface ZFTokenTextField ()
- (NSString *)rawText;
@end

@implementation ZFTokenTextField

- (void)setText:(NSString *)text
{
    if ([text isEqualToString:@""]) {
        if (((ZFTokenField *)self.superview.superview).numberOfToken > 0) {
            text = @"\u200B";
        }
    }
    [super setText:text];
}

- (NSString *)text
{
    return [super.text stringByReplacingOccurrencesOfString:@"\u200B" withString:@""];
}

- (NSString *)rawText
{
    return super.text;
}

- (void)addGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
{
    //Prevent zooming
    if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        gestureRecognizer.enabled = NO;
    }
    [super addGestureRecognizer:gestureRecognizer];
    return;
}

@end

@interface ZFTokenField () <UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) ZFTokenTextField *textField;
@property (nonatomic, strong) NSMutableArray *tokenViews;
@property (nonatomic, strong) UIView *focusedTokenView;

@property (nonatomic, strong) NSString *tempTextFieldText;

@property (nonatomic, strong) UIScrollView *scrollView;
@end

@implementation ZFTokenField

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setup];
}

- (BOOL)focusOnTextField
{
    [self.textField becomeFirstResponder];
    return YES;
}

#pragma mark -

- (void)setup
{
    self.clipsToBounds = YES;
    [self addTarget:self action:@selector(focusOnTextField) forControlEvents:UIControlEventTouchUpInside];
    
    self.textField = [[ZFTokenTextField alloc] init];
    self.textField.borderStyle = UITextBorderStyleNone;
    self.textField.backgroundColor = [UIColor clearColor];
    self.textField.delegate = self;
    [self.textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.scrollsToTop = false;
    
    [self reloadData];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self invalidateIntrinsicContentSize];
    
    NSEnumerator *tokenEnumerator = [self.tokenViews objectEnumerator];
    [self enumerateItemRectsUsingBlock:^(CGRect itemRect) {
        UIView *token = [tokenEnumerator nextObject];
        [token setFrame:itemRect];
    }];
    
    self.scrollView.frame = self.bounds;
}

- (CGSize)intrinsicContentSize
{
    if (!self.tokenViews) {
        return CGSizeZero;
    }
    
    __block CGRect totalRect = CGRectNull;
    [self enumerateItemRectsUsingBlock:^(CGRect itemRect) {
        totalRect = CGRectUnion(itemRect, totalRect);
    }];
    
    self.scrollView.contentSize = totalRect.size;
    return self.bounds.size;
}

#pragma mark - Public

- (void)reloadData
{
    // clear
    for (UIView *view in self.tokenViews) {
        [view removeFromSuperview];
    }
    self.tokenViews = [NSMutableArray array];
    
    if (self.dataSource) {
        NSUInteger count = [self.dataSource numberOfTokenInField:self];
        for (int i = 0 ; i < count ; i++) {
            UIView *tokenView = [self.dataSource tokenField:self viewForTokenAtIndex:i];
            tokenView.autoresizingMask = UIViewAutoresizingNone;
            tokenView.tag = i;
            tokenView.userInteractionEnabled = YES;
            
            UITapGestureRecognizer *gestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                                action:@selector(tokenDidTapped:)];
            [tokenView addGestureRecognizer:gestureRecognizer];
            
            [self.scrollView addSubview:tokenView];
            [self.tokenViews addObject:tokenView];
        }
    }
    
    [self.tokenViews addObject:self.textField];
    [self.scrollView addSubview:self.textField];
    self.textField.frame = (CGRect) {0,0,50,[self.dataSource lineHeightForTokenInField:self]};
    
    [self invalidateIntrinsicContentSize];
    [self.textField setText:@""];
    
    self.scrollView.frame = self.bounds;
    [self addSubview:self.scrollView];
}

- (NSUInteger)numberOfToken
{
    return self.tokenViews.count - 1;
}

- (NSUInteger)indexOfTokenView:(UIView *)view
{
    return [self.tokenViews indexOfObject:view];
}

#pragma mark - Private

- (void)enumerateItemRectsUsingBlock:(void (^)(CGRect itemRect))block
{
    NSUInteger rowCount = 0;
    CGFloat x = 0, y = 0;
    CGFloat margin = 0;
    CGFloat lineHeight = [self.dataSource lineHeightForTokenInField:self];
    
    if ([self.delegate respondsToSelector:@selector(tokenMarginInTokenInField:)]) {
        margin = [self.delegate tokenMarginInTokenInField:self];
    }
    
    for (UIView *token in self.tokenViews) {
        CGFloat tokenWidth = MIN(CGRectGetWidth(self.bounds), CGRectGetWidth(token.frame));
        
        if ([token isKindOfClass:[ZFTokenTextField class]]) {
            UITextField *textField = (UITextField *)token;
            CGSize size = [textField sizeThatFits:(CGSize){CGRectGetWidth(self.bounds), lineHeight}];
            size.width += 20;
            size.height = lineHeight;
            
            if (size.width > CGRectGetWidth(self.bounds)) {
                size.width = CGRectGetWidth(self.bounds);
            }
            token.frame = (CGRect){{x, y}, size};
        }
        
        block((CGRect){x, y, tokenWidth, token.frame.size.height});
        x += tokenWidth + margin;
        rowCount++;
    }
}

- (void)adjustContentOffset {
    CGSize size = self.scrollView.contentSize;
    CGFloat width = CGRectGetWidth(self.scrollView.bounds);
    
    [self.scrollView scrollRectToVisible:CGRectMake(size.width - width, 0, width, size.height)
                                animated:NO];
}

- (void)removeTokenAtIndex:(NSUInteger)index {
    [self.tokenViews[index] removeFromSuperview];
    [self.tokenViews removeObjectAtIndex:index];
    
    [self.textField setText:@""];
    
    if ([self.delegate respondsToSelector:@selector(tokenField:didRemoveTokenAtIndex:)]) {
        [self.delegate tokenField:self didRemoveTokenAtIndex:index];
    }
}

#pragma mark - GestureRecognizer
- (void)tokenDidTapped:(UITapGestureRecognizer *)gestureRecognizer {
    if (self.focusedTokenView == gestureRecognizer.view) {
        if ([self.focusedTokenView respondsToSelector:@selector(tokenDidUnFocused:)]) {
            [(id<ZFTokenDelegate>)self.focusedTokenView tokenDidUnFocused:self];
        }
        
        self.focusedTokenView = nil;
        
    } else {
        if ([self.focusedTokenView respondsToSelector:@selector(tokenDidUnFocused:)]) {
            [(id<ZFTokenDelegate>)self.focusedTokenView tokenDidUnFocused:self];
        }
        
        if ([gestureRecognizer.view respondsToSelector:@selector(tokenDidFocused:)]) {
            [(id<ZFTokenDelegate>)gestureRecognizer.view tokenDidFocused:self];
        }
        
        self.focusedTokenView = gestureRecognizer.view;
    }
}


#pragma mark - TextField

- (void)textFieldDidBeginEditing:(ZFTokenTextField *)textField
{
    self.tempTextFieldText = [textField rawText];
    
    if ([self.delegate respondsToSelector:@selector(tokenFieldDidBeginEditing:)]) {
        [self.delegate tokenFieldDidBeginEditing:self];
    }
}

- (BOOL)textFieldShouldEndEditing:(ZFTokenTextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenFieldShouldEndEditing:)]) {
        return [self.delegate tokenFieldShouldEndEditing:self];
    }
    return YES;
}

- (void)textFieldDidEndEditing:(ZFTokenTextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenFieldDidEndEditing:)]) {
        [self.delegate tokenFieldDidEndEditing:self];
    }
}

- (void)textFieldDidChange:(ZFTokenTextField *)textField
{
    if ([[textField rawText] isEqualToString:@""]) {
        textField.text = @"\u200B";
        
        if (self.focusedTokenView) {
            NSUInteger removeIndex = [self.tokenViews indexOfObject:self.focusedTokenView];
            if (removeIndex == NSNotFound) {
                self.focusedTokenView = nil;
                return;
            }
            [self removeTokenAtIndex:removeIndex];
            [self reloadData];
            return;
            
        } else if ([self.tempTextFieldText isEqualToString:@"\u200B"]) {
            if (self.tokenViews.count > 1) {
                NSUInteger removeIndex = self.tokenViews.count - 2;
                [self removeTokenAtIndex:removeIndex];
            }
        }
    }
    
    self.tempTextFieldText = [textField rawText];
    [self invalidateIntrinsicContentSize];
    
    if ([self.delegate respondsToSelector:@selector(tokenField:didTextChanged:)]) {
        [self.delegate tokenField:self didTextChanged:textField.text];
    }
    
    [self adjustContentOffset];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([self.delegate respondsToSelector:@selector(tokenField:didReturnWithText:)]) {
        [self.delegate tokenField:self didReturnWithText:textField.text];
    }
    return YES;
}

@end