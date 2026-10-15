package {
    import flash.events.KeyboardEvent;
    public final class KeybindFixtureAPI {
        public var keybindVersion:int=0;
        public var capture:Boolean=false;
        public var suppressed:Boolean=false;
        public var matchingCalls:int=0;
        public var heldCalls:int=0;
        public var rejectedPages:int=0;
        public var pages:Object={};
        private var down:Object={};
        private var ctrl:Boolean=false,alt:Boolean=false,shift:Boolean=false;
        public function registerPage(id:String,name:String,items:Array,close:Function=null,desc:String="",navigation:Object=null):void {
            for each(var item:Object in items) if(item.kind=="keybind" && keybindVersion<1) {rejectedPages++;return;}
            pages[id]={modId:id,items:items,navigation:navigation};
        }
        public function item(action:String):Object {
            for each(var value:Object in pages["light-and-darkness-hotkeys"].items) if(value.key==action) return value;
            throw new Error("missing fixture action");
        }
        public function feed(event:KeyboardEvent):void {
            if(event.type==KeyboardEvent.KEY_DOWN) down[event.keyCode]=true;else delete down[event.keyCode];
            ctrl=event.ctrlKey;alt=event.altKey;shift=event.shiftKey;
            if(event.type==KeyboardEvent.KEY_UP) {
                if(event.keyCode==17) ctrl=false;if(event.keyCode==18) alt=false;if(event.keyCode==16) shift=false;
            }
        }
        public function matchesKey(page:String,action:String,event:KeyboardEvent):Boolean {
            matchingCalls++;var value:Object=item(action).get();
            return !capture && !suppressed && page=="light-and-darkness-hotkeys" && value.code!=0 && value.code==event.keyCode &&
                value.ctrl==event.ctrlKey && value.alt==event.altKey && value.shift==event.shiftKey;
        }
        public function isKeyDown(page:String,action:String):Boolean {
            heldCalls++;var value:Object=item(action).get();
            return !capture && !suppressed && page=="light-and-darkness-hotkeys" && value.code!=0 && Boolean(down[value.code]) &&
                value.ctrl==ctrl && value.alt==alt && value.shift==shift;
        }
        public function isCapturingKey():Boolean {return capture;}
    }
}
