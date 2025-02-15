/**
 * Appcelerator Titanium Mobile
 * Copyright (c) 2009-2013 by Appcelerator, Inc. All Rights Reserved.
 * Licensed under the terms of the Apache Public License
 * Please see the LICENSE included with this distribution for details.
 */

#import "ComPolancomediaMapboxView.h"
#import "TiUtils.h"
#import "Mapbox.h"

@implementation ComPolancomediaMapboxView

#pragma mark Lifecycle

-(void)initializeState
{
	// This method is called right after allocating the view and
	// is useful for initializing anything specific to the view
    
    [self addMap];
    
	[super initializeState];
	
	NSLog(@"[VIEW LIFECYCLE EVENT] initializeState");
}

-(void)configurationSet
{
	// This method is called right after all view properties have
	// been initialized from the view proxy. If the view is dependent
	// upon any properties being initialized then this is the method
	// to implement the dependent functionality.
	
	[super configurationSet];
	
	NSLog(@"[VIEW LIFECYCLE EVENT] configurationSet");
}

-(void)dealloc
{
    RELEASE_TO_NIL(mapView);
    [super dealloc];
    
    NSLog(@"[VIEW LIFECYCLE EVENT] dealloc");
}

-(void)willMoveToSuperview:(UIView *)newSuperview
{
	NSLog(@"[VIEW LIFECYCLE EVENT] willMoveToSuperview");
}

#pragma mark private

-(void)addMap
{
    if(mapView==nil)
    {
        NSLog(@"[VIEW LIFECYCLE EVENT] addMap");
        
        NSString *mapPath = [TiUtils stringValue:[self.proxy valueForKey:@"map"]];
        id mapSource;
        
        //check if file exists in AppData dir, otherwise try Resources
        BOOL fileExistsAppData = [[NSFileManager defaultManager] fileExistsAtPath:mapPath];
        NSLog(@"mapFile exists in AppData: %i", fileExistsAppData);
        
        //check if file exists in default Resources dir, otherwise try to add remote map
        NSString *mapInResourcesFolder = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: mapPath ];
        
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:mapInResourcesFolder];
        NSLog(@"mapFile exists in Resources (default): %i", fileExists);
        
        if( fileExistsAppData)
        {
            mapSource = [[RMMBTilesSource alloc] initWithTileSetURL:[NSURL fileURLWithPath:mapPath]];  //arshavinho credit
            // In Titanium use:
            // var file = Titanium.Filesystem.getFile(Titanium.Filesystem.applicationDataDirectory, 'map.mbtiles');
            //...{ map: filePath.resolve()  ... }
        }
        else if(fileExists)
        {
            mapSource = [[RMMBTilesSource alloc] initWithTileSetResource:mapPath ofType:@"mbtiles"];
            
        } else
        {
            NSString *tkn = [TiUtils stringValue:[self.proxy valueForKey:@"accessToken"]];
            [[RMConfiguration configuration] setAccessToken:tkn];
            mapSource = [[RMMapboxSource alloc] initWithMapID:mapPath];

        }
        
        /*create the mapView with CGRectMake upon initialization because we won't know frame size
        until frameSizeChanged is fired after loading view. If we wait until then, we can't add annotations.*/
        mapView = [[RMMapView alloc] initWithFrame:CGRectMake(0, 0, 320, 480) andTilesource:mapSource];
        mapView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
        mapView.adjustTilesForRetinaDisplay = YES; // these tiles aren't designed specifically for retina, so make them legible
        
        [self addSubview:mapView];
        mapView.delegate = self;
    }
}

-(void)frameSizeChanged:(CGRect)frame bounds:(CGRect)bounds
{
    NSLog(@"[VIEW LIFECYCLE EVENT] frameSizeChanged");
    if (mapView!=nil)
    {
        [TiUtils setView:mapView positionRect:bounds];
    }
    else
    {
        [self addMap];
    }
}

#pragma mark Property Setters

-(void)setBackgroundColor_:(id)value
{
    [mapView setBackgroundColor:[[TiUtils colorValue:value] _color]];
}

-(void)setCenterLatLng_:(id)value
{
    [mapView setCenterCoordinate: CLLocationCoordinate2DMake([TiUtils floatValue:[value objectAtIndex:0]],[TiUtils floatValue:[value objectAtIndex:1]])];
}

-(void)setDebugTiles_:(id)value
{
	[mapView setDebugTiles:[TiUtils boolValue:value]];
}

-(void)setHideAttribution_:(id)value
{
    mapView.hideAttribution = [TiUtils boolValue:value];
}

-(void)setMinZoom_:(id)value
{
    [mapView setMinZoom:[TiUtils floatValue:value]];
}

-(void)setMaxZoom_:(id)value
{
    [mapView setMaxZoom:[TiUtils floatValue:value]];
}

-(void)setUserLocation_:(id)value
{
    mapView.showsUserLocation = [TiUtils boolValue:value];
}

-(void)setZoom_:(id)value
{
    [mapView setZoom:[TiUtils floatValue:value] animated:true];
}

#pragma mark Public Methods
-(void)clearTileCache:(id)args
{
    [mapView removeAllCachedImages];
}

#pragma mark Annotations

//add annotation via setter
-(void)setAnnotation_:(id)args
{
    [self addAnnotation:args];
}

-(void)removeAnnotation:(id)args
{
    ENSURE_SINGLE_ARG(args,NSObject);
    NSString *title;
	
	if ([args isKindOfClass:[NSString class]])
	{
		title = [TiUtils stringValue:args];
    }
    else if([args isKindOfClass:[NSDictionary class]]){
        title = [TiUtils stringValue:[args objectForKey:@"title"]];
    }
    for (RMAnnotation *an in mapView.annotations)
	{
        if(!an.isUserLocationAnnotation)
        {
            if ([title isEqualToString:an.title])
            {
                TiThreadPerformOnMainThread(^{[mapView removeAnnotation:an];}, NO);
                break;
            }
        }
    }
}

-(void)removeAllAnnotations:(id)args
{
    ENSURE_UI_THREAD(removeAllAnnotations, args);
    [mapView removeAllAnnotations];
}


#pragma mark Events

- (void)longPressOnMap:(RMMapView *)map at:(CGPoint)point
{
	if ([self.proxy _hasListeners:@"longPressOnMap"]) {
		NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSString stringWithFormat:@"%f",[mapView pixelToCoordinate:point].longitude],@"longitude",
                               [NSString stringWithFormat:@"%f",[mapView pixelToCoordinate:point].latitude],@"latitude",
                               nil
                               ];
        
		[self.proxy fireEvent:@"longPressOnMap" withObject:event];
	}
}

- (void)mapViewRegionDidChange:(RMMapView *)map
{
	if ([self.proxy _hasListeners:@"mapViewRegionDidChange"]) {
        
        NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSString stringWithFormat:@"%f",[map centerCoordinate].latitude], @"latitude",
                               [NSString stringWithFormat:@"%f",[map centerCoordinate].longitude], @"longitude",nil];
		[self.proxy fireEvent:@"mapViewRegionDidChange" withObject:event];
	}
}

- (void)singleTapOnMap:(RMMapView *)mapView at:(CGPoint)point
{
	// The event listeners for a view are actually attached to the view proxy.
	// You must reference 'self.proxy' to get the proxy for this view
	
	// It is a good idea to check if there are listeners for the event that
	// is about to fired. There could be zero or multiple listeners for the
	// specified event.
	if ([self.proxy _hasListeners:@"singleTapOnMap"]) {
        
		NSDictionary *event = [NSDictionary dictionaryWithObjectsAndKeys:
                               [NSString stringWithFormat:@"%f",[mapView pixelToCoordinate:point].longitude],@"longitude",
                               [NSString stringWithFormat:@"%f",[mapView pixelToCoordinate:point].latitude],@"latitude",
                               nil
                               ];
        
		[self.proxy fireEvent:@"singleTapOnMap" withObject:event];
	}
}

-(void)tapOnAnnotation:(RMAnnotation *)annotation onMap:(RMMapView *)map
{
    if ([self.proxy _hasListeners:@"tapOnAnnotation"]) {
        
        NSDictionary *event = [annotation.userInfo objectForKey:@"args"];
        
		[self.proxy fireEvent:@"tapOnAnnotation" withObject:event];
	}
}

//add annotation via public api
-(void)addAnnotation:(id)args
{
    ENSURE_TYPE(args,NSDictionary);
	ENSURE_UI_THREAD(addAnnotation,args);
    
    RMAnnotation *annotation = [[RMAnnotation alloc]
                                initWithMapView:mapView
                                coordinate:CLLocationCoordinate2DMake([TiUtils floatValue:[args objectForKey:@"latitude"]],[TiUtils floatValue:[args objectForKey:@"longitude"]])
                                andTitle:[TiUtils stringValue:[args objectForKey:@"title"]]
                                ];
    
    annotation.subtitle = [TiUtils stringValue:[args objectForKey:@"subtitle"]];
    
    //Attach all data for use when creating the layer for the annotation
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              args, @"args",
                              @"Marker", @"type", nil];
    
    annotation.userInfo = userInfo;
    
    [mapView addAnnotation:annotation];
}

//parts of addShape from https://github.com/benbahrenburg/benCoding.Map addPolygon method Apache License 2.0
-(void)addShape:(id)args
{
	ENSURE_TYPE(args,NSDictionary);
	ENSURE_UI_THREAD(addShape,args);
    
    id pointsValue = [args objectForKey:@"points"];
    
    //remove points from args since they are no longer needed
    //and we are passing args along to the annotation userInfo
    NSMutableDictionary *mutableArgs = [args mutableCopy];
    [mutableArgs removeObjectForKey:@"points"];
    
    if(pointsValue==nil)
    {
        NSLog(@"points value is missing, cannot add polygon");
        return;
    }
    NSArray *inputPoints = [NSArray arrayWithArray:pointsValue];
    //Get our counter
    NSUInteger pointsCount = [inputPoints count];
    
    //We need at least one point to do anything
    if(pointsCount==0){
        return;
    }
    
    //Create the number of points provided
    NSMutableArray *points = [[NSMutableArray alloc] init];
    
    //loop through and add coordinates
    for (int iLoop = 0; iLoop < pointsCount; iLoop++) {
        [points addObject:
         [[CLLocation alloc] initWithLatitude:[TiUtils floatValue:@"latitude" properties:[inputPoints objectAtIndex:iLoop] def:0]
                                    longitude:[TiUtils floatValue:@"longitude" properties:[inputPoints objectAtIndex:iLoop] def:0] ]];
 }
    
    RMAnnotation *annotation = [[RMAnnotation alloc]
                                initWithMapView:mapView
                                coordinate:((CLLocation *)[points objectAtIndex:0]).coordinate
                                andTitle:[TiUtils stringValue:@"title" properties:mutableArgs]];
    
    //Attach all data for use when creating the layer for the annotation
    NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                              mutableArgs, @"args",
                              points, @"points",
                              @"Shape", @"type", nil];
    
    annotation.userInfo = userInfo;
    
    [mapView addAnnotation:annotation];
}


//This event that adds layer for any annotation created with RMAnnotation
- (RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation
{
    //check for user location annotation
    if (annotation.isUserLocationAnnotation)
        return nil;
    
    NSDictionary *userInfo = [NSDictionary dictionaryWithDictionary:annotation.userInfo];
    
    NSString *type = [userInfo objectForKey:@"type"];
    
    //Shape
    if([type isEqual: @"Shape"])
    {
        return [self shapeLayer:mapView userInfo:userInfo];
    }
    else if([type isEqual: @"Marker"])
    {
        return [self markerLayer:mapView userInfo:userInfo];
    }
}

- (RMMapLayer *)markerLayer:(RMMapView *)mapView userInfo:(NSDictionary *)userInfo
{
    NSDictionary *args = [userInfo objectForKey:@"args"];
    
    UIColor *tintColor =  [[TiUtils colorValue:@"tintColor" properties:[userInfo objectForKey:@"args"]] _color];
    if (tintColor == nil)
    {
        tintColor = (mapView.tintColor ? mapView.tintColor : nil);
    }
    NSLog(@"Marker color: %i", tintColor);
    
    RMMarker *marker;
    
    if([TiUtils stringValue:@"markerImage" properties:args])
    {
        NSString *markerImage = [TiUtils stringValue:@"markerImage" properties:args ];
        marker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed: markerImage ]];
    }else{
        marker = [[RMMarker alloc] initWithMapboxMarkerImage:nil tintColor: tintColor];
    }
    
    marker.canShowCallout = YES;
    
    return marker;
}

- (RMMapLayer *)shapeLayer:(RMMapView *)mapView userInfo:(NSDictionary *)userInfo
{
    RMShape *shape = [[RMShape alloc] initWithView:mapView];
    NSDictionary *args = [userInfo objectForKey:@"args"];
    
    //FILL
    float fillOpacity = [TiUtils floatValue:@"fillOpacity" properties:args];
    UIColor *fillColor =  [[TiUtils colorValue:@"fillColor" properties:[userInfo objectForKey:@"args"]] _color];
    
    if (fillColor != nil)
    {
        if(fillOpacity)
        {
            fillColor = [fillColor colorWithAlphaComponent:fillOpacity];
        }
        shape.fillColor = fillColor;
    }
    
    //Line Properties
    float lineOpacity = [TiUtils floatValue:@"lineOpacity" properties:args];
    UIColor *lineColor =  [[TiUtils colorValue:@"lineColor" properties:[userInfo objectForKey:@"args"]] _color];
    if (lineColor != nil)
    {
        if(lineOpacity)
        {
            lineColor = [lineColor colorWithAlphaComponent:lineOpacity];
        }
        shape.lineColor = lineColor;
    }
    shape.lineWidth = [TiUtils floatValue:@"lineWidth" properties:args def: 1.0];
    
    shape.lineDashLengths = [args objectForKey:@"lineDashLengths" ];
    shape.lineDashPhase = [TiUtils floatValue:@"lineDashPhase" properties:args def: 0.0];
    shape.scaleLineDash = [TiUtils boolValue:@"scaleLineDash" properties:args def: NO];
    shape.lineJoin = [TiUtils stringValue:@"lineJoin" properties:args def:kCALineJoinMiter];

    //Add shape with coordinates
    for (CLLocation *location in (NSArray *)[userInfo objectForKey:@"points"])
        [shape addLineToCoordinate:location.coordinate];
    
    return shape;
}
@end
