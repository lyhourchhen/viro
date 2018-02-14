//
//  VRTARImageMarker.mm
//  ViroReact
//
//  Created by Andy Chu on 2/2/18.
//  Copyright © 2018 Viro Media. All rights reserved.
//

#import "VRTARImageMarker.h"
#import "VRTARTrackingTargetsModule.h"

@implementation VRTARImageMarker {
    /*
     Whether or not we need to update the underlying VRONode.
     */
    bool _shouldUpdate;

    /*
     True if we should add the VRONode to the declarativeSession on the next component update. Otherwise,
     we'll just call update.
     */
    bool _needsAddToScene;
}

- (instancetype)initWithBridge:(RCTBridge *)bridge {
    self = [super initWithBridge:bridge];
    if (self) {
        _arNodeDelegate = std::make_shared<VROARNodeDelegateiOS>(self);
        _shouldUpdate = false;
        _needsAddToScene = true;
        
        std::shared_ptr<VROARDeclarativeImageNode> imageNode = std::dynamic_pointer_cast<VROARDeclarativeImageNode>([self node]);
        imageNode->setARNodeDelegate(_arNodeDelegate);
    }
    return self;
}

- (std::shared_ptr<VROARDeclarativeSession>)declarativeSession {
    return std::dynamic_pointer_cast<VROARScene>([self scene])->getDeclarativeSession();
}

- (void)setTarget:(NSString *)target {
    _target = target;
    _shouldUpdate = true;
}

- (void)parentDidDisappear {
    if ([self scene]) {
        [self declarativeSession]->removeARNode(std::dynamic_pointer_cast<VROARDeclarativeImageNode>(self.node));
    }
    [super parentDidDisappear];
}

- (void)setScene:(std::shared_ptr<VROScene>)scene {
    [super setScene:scene];
    
    // If the scene is finally set, then just invoke didSetProps again to fetch the target
    // and add the VROARDeclarativeImageNode to the VROARScene.
    [self didSetProps:nil];
}

- (void)didSetProps:(NSArray<NSString *> *)changedProps {
    if ([self scene] && _shouldUpdate) {
        [self getARTargetShouldAdd:_needsAddToScene];
        _shouldUpdate = false;
        _needsAddToScene = false; // we should only add on the first invocation of getARTargetShouldAdd, otherwise, just update.
    }
}

- (void)getARTargetShouldAdd:(BOOL)needsAddToScene {
    VRTARTrackingTargetsModule *trackingTargetsModule = [self.bridge moduleForClass:[VRTARTrackingTargetsModule class]];
    VRTARTargetPromise *promise = [trackingTargetsModule getARTargetPromise:_target];
    if (promise) {
        __weak VRTARImageMarker *weakSelf = self;
        VRTARTargetPromiseCompletion completion = ^(NSString *targetName, std::shared_ptr<VROARImageTarget> target) {
            __strong VRTARImageMarker *strongSelf = weakSelf;
            // make sure the VRTARImageMarker is still around and the target hasn't changed since we created the block.
            if (strongSelf && [targetName isEqualToString:strongSelf.target] && target) {
                std::shared_ptr<VROARDeclarativeImageNode> imageNode = std::dynamic_pointer_cast<VROARDeclarativeImageNode>(strongSelf.node);
                std::shared_ptr<VROARImageTarget> oldTarget = imageNode->getImageTarget();
                imageNode->setImageTarget(target);
                std::shared_ptr<VROARScene> arScene = std::dynamic_pointer_cast<VROARScene>(strongSelf.scene);
                if (arScene) {
                    if (needsAddToScene) {
                        // add the ARNode
                        [strongSelf declarativeSession]->addARNode(imageNode);
                    } else {
                        // remove the old ARImageTarget and update the ARNode
                        [strongSelf declarativeSession]->removeARImageTarget(oldTarget);
                        [strongSelf declarativeSession]->updateARNode(imageNode);
                    }
                    // always add the new ARImageTarget
                    [strongSelf declarativeSession]->addARImageTarget(target);
                }
            }
        };
        [promise wait:completion];
    } else {
        RCTLogError(@"[ViroARImageMarker] Unable to find target with name [%@]. Have you created it?", _target);
    }
}


- (std::shared_ptr<VRONode>)createVroNode {
    return std::make_shared<VROARDeclarativeImageNode>();
}

@end