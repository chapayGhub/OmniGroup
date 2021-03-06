// Copyright 2005-2008, 2010, 2012 Omni Development, Inc. All rights reserved.
//
// This software may only be used and reproduced according to the
// terms in the file OmniSourceLicense.html, which should be
// distributed with this project and can also be found at
// <http://www.omnigroup.com/developer/sourcecode/sourcelicense/>.

#import "OITabCell.h"

#define USE_CORE_IMAGE

#import <OmniBase/OmniBase.h>
#import <OmniAppKit/OmniAppKit.h>
#ifdef USE_CORE_IMAGE
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h> // For CoreImage
#endif

RCS_ID("$Id$");

NSString *TabTitleDidChangeNotification = @"TabTitleDidChange";

@interface OITabCell (/*Private*/)
#ifdef USE_CORE_IMAGE
- (void)_deriveImages;
#endif
- (void)_drawImageInRect:(NSRect)cellFrame inView:(NSView *)controlView;
@end

@implementation OITabCell

- (void)dealloc
{
    [grayscaleImage release];
    [dimmedImage release];
    [_imageCell release];
    [super dealloc];
}

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return [NSColor blueColor];
}

- (BOOL)duringMouseDown;
{
    return duringMouseDown;
}

- (void)saveState;
{
    duringMouseDown = YES;
    oldState = [self state];
}

- (void)clearState;
{
    duringMouseDown = NO;
}

- (void)setDimmed:(BOOL)value
{
    dimmed = value;
}

- (BOOL)dimmed
{
    return dimmed;
}

- (BOOL)isPinned;
{
    return isPinned;
}

- (void)setIsPinned:(BOOL)newValue;
{
    // If we get pinned, make sure we are turned on
    if (newValue && ([self state] != NSOnState)) {
        [self setState:NSOnState];
    }
    
    isPinned = newValue;    // Set our state to On before turning on pinning, so that we're always in a consistent state (can't be pinned and not on)
}

- (void)setState:(NSInteger)value
{
    // If we're pinned, don't allow ourself to be turned off
    if (isPinned) {
        return;
    }
    
    [super setState:value];
    if (duringMouseDown)
        [[NSNotificationCenter defaultCenter] postNotificationName:TabTitleDidChangeNotification object:self];
}

- (NSImage *)grayscaleImage
{
    if (grayscaleImage)
        return grayscaleImage;
#ifndef USE_CORE_IMAGE
    [[self image] lockFocus];
    NSBitmapImageRep *sourceRep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0,0,24,24)];
    [[self image] unlockFocus];
    unsigned int patternBytesPerRow = [sourceRep bytesPerRow];
    unsigned char *patternData = [sourceRep bitmapData];
    unsigned int i, j;
    
#define WITH_ALPHA_IN_PIXEL(data, i,j) ((unsigned char *)&data[(j)*patternBytesPerRow + (i)*4])
    for(i=0;i<24;i++) {
        for(j=0;j<24;j++) {
            unsigned char *inPixel = WITH_ALPHA_IN_PIXEL(patternData,i,j);
            unsigned int redBits   = inPixel[0];
            unsigned int greenBits = inPixel[1];
            unsigned int blueBits  = inPixel[2];
            float red = .3 * redBits/255.0;
            float green = 0.59 * greenBits/255.0;
            float blue = 0.11 * blueBits/255.0;
            unsigned int gray = MIN(255.0, 255.0 * (red + green + blue));
            inPixel[0] =  gray;
            inPixel[1] =  gray;
            inPixel[2] =  gray;
        }
    }
    grayscaleImage = [[NSImage alloc] initWithSize:NSMakeSize(24, 24)];
    [grayscaleImage addRepresentation:sourceRep];
    [sourceRep release];
#else /* USE_CORE_IMAGE */
    [self _deriveImages];
#endif /* USE_CORE_IMAGE */
    return grayscaleImage;
}

- (NSImage *)dimmedImage
{
    if (dimmedImage)
        return dimmedImage;
#ifndef USE_CORE_IMAGE
    dimmedImage = [[NSImage alloc] initWithSize:[[self image] size]];
    [dimmedImage setFlipped:YES];
    [dimmedImage lockFocus];
    NSRect fooRect = NSMakeRect(0,0,[dimmedImage size].width, [dimmedImage size].height);
    NSRectFillUsingOperation(fooRect, NSCompositeClear);
    [[self image] drawFlippedInRect:fooRect operation:NSCompositeSourceOver];
    [[NSColor colorWithCalibratedWhite:0.1 alpha:0.5] set];
    NSRectFillUsingOperation(fooRect, NSCompositeSourceOver);
    [[self image] drawFlippedInRect:fooRect operation:NSCompositeDestinationIn];
    [dimmedImage unlockFocus];
#else /* USE_CORE_IMAGE */
    [self _deriveImages];
#endif /* USE_CORE_IMAGE */
    return dimmedImage;
}

- (BOOL)drawState
{
    return (duringMouseDown) ? oldState : [self state];
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    if (![self image])
        return;
    
    // The highlight is now drawn by the matrix so that parts can be behind all cells and parts can be in front of all cells, etc.

    NSRect imageRect;
    imageRect.size = NSMakeSize(24,24);
    imageRect.origin.x = (CGFloat)(cellFrame.origin.x + floor((cellFrame.size.width - imageRect.size.width)/2));
    imageRect.origin.y = (CGFloat)(cellFrame.origin.y + floor((cellFrame.size.height - imageRect.size.height)/2));
    
    [self _drawImageInRect:imageRect inView:controlView];

    if (isPinned) {
        NSImage *image = [NSImage imageNamed:@"OITabLock.pdf" inBundle:OMNI_BUNDLE];
        NSPoint point = NSMakePoint(NSMaxX(cellFrame) - [image size].width - 3.0f, NSMaxY(cellFrame) - 2.0f);
        [image compositeToPoint:point operation:NSCompositeSourceOver];
    }
    
    return;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    OITabCell *copy = [super copyWithZone:zone];
    copy->grayscaleImage = [grayscaleImage retain];
    copy->dimmedImage = [dimmedImage retain];
    copy->_imageCell = [_imageCell copy];

    return copy;
}

#pragma mark - Private

#ifdef USE_CORE_IMAGE

// This should only be called when we're lockFocused on our view, so that we'll get an appropriate CIContext for our window.
- (void)_deriveImages;
{
    CIContext *ctx = [[NSGraphicsContext currentContext] CIContext];
    CGFloat scale = 1;
    if ([[NSScreen mainScreen] respondsToSelector:@selector(backingScaleFactor)])
        scale = [[NSScreen mainScreen] backingScaleFactor];
    CIImage *sourceImage = [[self image] ciImageForContext:ctx scale:scale];
    NSCIImageRep *filteredImageRep;
    
    CIFilter *grayedFilter = [CIFilter filterWithName:@"CIColorControls"
                                        keysAndValues:
                              kCIInputBrightnessKey, [NSNumber numberWithFloat:0.0f],
                              kCIInputContrastKey, [NSNumber numberWithFloat:0.85f],
                              kCIInputSaturationKey, [NSNumber numberWithFloat:0.0f],
                              kCIInputImageKey, sourceImage,
                              nil];
    
    filteredImageRep = [[NSCIImageRep alloc] initWithCIImage:[grayedFilter valueForKey:kCIOutputImageKey]];
    [grayscaleImage release];
    
    NSSize imageSize = [[self image] size];    
    grayscaleImage = [[NSImage alloc] initWithSize:imageSize];
    [grayscaleImage addRepresentation:filteredImageRep];
    [filteredImageRep release];
    
    static const CGFloat redVector[4]   = { 0.8f, 0.0f, 0.0f, 0.0f };
    static const CGFloat greenVector[4] = { 0.0f, 0.8f, 0.0f, 0.0f };
    static const CGFloat blueVector[4]  = { 0.0f, 0.0f, 0.8f, 0.0f };
    static const CGFloat alphaVector[4] = { 0.0f, 0.0f, 0.0f, 1.0f };
    static const CGFloat biasVector[4]  = { 0.2f, 0.2f, 0.2f, 0.0f };
    
    CIFilter *dimmedFilter = [CIFilter filterWithName:@"CIColorMatrix"
                                        keysAndValues:
                              @"inputRVector", [CIVector vectorWithValues:redVector count:4],
                              @"inputGVector", [CIVector vectorWithValues:greenVector count:4],
                              @"inputBVector", [CIVector vectorWithValues:blueVector count:4],
                              @"inputAVector", [CIVector vectorWithValues:alphaVector count:4],
                              @"inputBiasVector", [CIVector vectorWithValues:biasVector count:4],
                              kCIInputImageKey, sourceImage,
                              nil];
    
    filteredImageRep = [[NSCIImageRep alloc] initWithCIImage:[dimmedFilter valueForKey:kCIOutputImageKey]];
    [dimmedImage release];
    dimmedImage = [[NSImage alloc] initWithSize:imageSize];
    [dimmedImage addRepresentation:filteredImageRep];
    [filteredImageRep release];
}

#endif /* USE_CORE_IMAGE */

- (void)_drawImageInRect:(NSRect)cellFrame inView:(NSView *)controlView;
{
    // Non-template images may be dimmed or made grayscale, depending on the context. That's incompatible with template images, so for them we instead adjust the bckgroundStyle, which will result in different treatment of the template.
    BOOL drawHighlighted = duringMouseDown && [self isHighlighted]; // Have to check duringMouseDown as well, because the first cell is often highlighted at launch, so we would draw highlighted even though the user hadn't clicked on us yet.
    NSImage *image = [self image];
    if (![image isTemplate]) {
        if (drawHighlighted) {
            image = [self dimmedImage];
        } else if (dimmed) {
            image = [self grayscaleImage];
        }
    }
    
    // Let an image cell draw the image, because it knows how to handle template images, and won't draw any background. (We can't let our superclass do its own drawing, because NSButtonCell always draws its background, which would overlay the background being drawn for us by the OITabMatrix we are in.)
    if (_imageCell == nil) {
        _imageCell = [[NSImageCell alloc] initImageCell:nil];
    }
    [_imageCell setEnabled:!dimmed];
    [_imageCell setImage:image];
    [_imageCell setBackgroundStyle:(drawHighlighted ? NSBackgroundStyleLight : NSBackgroundStyleRaised)]; // Kind of interested in using NSBackgroundStyleLowered instead of NSBackgroundStyleLight when highlighted, but drawing after first click is delayed due to OITabMatrix looking for a second click, and the delay in the redraw was much more obvious (and flashy on single clicks) when the highlighted effect was so much more dramatic. Strangely, the very first click, if on the first tab and it's already selected (or some similar context), doesn't have this delay, but I didn't research that.
    [_imageCell drawInteriorWithFrame:cellFrame inView:controlView];
}

@end
