package lad {
    import flash.display.Sprite;
    import flash.text.TextField;
    import flash.text.TextFormat;
    public final class LadHud extends Sprite {
        private var label:TextField=new TextField();
        public function LadHud() {
            name="LightAndDarknessHUD";mouseEnabled=false;mouseChildren=false;
            label.defaultTextFormat=new TextFormat("Microsoft YaHei",13,0xffe7bb);
            label.width=460;label.height=66;label.multiline=true;label.selectable=false;
            addChild(label);
        }
        public function show(width:Number,headlamp:Boolean,hint:String,progress:Number,headlampKey:String="Alt+L"):void {
            x=Math.max(10,(width-460)/2);y=8;
            label.text="随身灯 "+(headlamp?"开":"关")+"  "+headlampKey+"\n"+hint;
            graphics.clear();graphics.beginFill(0x171b21,0.78);graphics.drawRoundRect(-8,-3,476,hint.length?68:33,8);graphics.endFill();
            if(progress>0) {graphics.beginFill(0xe4bb77);graphics.drawRect(0,59,450*Math.min(1,progress),3);graphics.endFill();}
        }
    }
}
