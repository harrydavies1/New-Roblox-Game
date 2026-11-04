#!/usr/bin/env python3
"""Optional documentation preview from real GUI contract geometry, not an engine screenshot.

Requires Pillow, which is not required to build/test the game.
"""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont, ImageChops

ROOT=Path(__file__).resolve().parents[1]


def main():
    for key,label in [('320','phone'),('1280','desktop'),('prize-phone','prize-phone'),('menu-desktop','menu-desktop'),('menu-phone','menu-phone'),('menu-landscape','menu-landscape'),('menu-rewards-phone','menu-rewards-phone')]:
        layout=json.loads((ROOT/'build'/f'ui-layout-{key}.json').read_text())
        w,h=int(layout['Width']),int(layout['Height'])
        image=Image.new('RGB',(w,h+36),(84,102,103)); draw=ImageDraw.Draw(image)
        for y in range(h):
            t=y/max(h-1,1)
            draw.line((0,y,w,y),fill=(int(84-22*t),int(102-24*t),int(103-20*t)))
        # A neutral layout ground; intentionally not presented as Roblox map rendering.
        for x in range(-h,w+h,70): draw.line((x,h*.4,x+h,h),fill=(77,94,94),width=1)
        for y in range(int(h*.4),h,50): draw.line((0,y,w,y),fill=(77,94,94),width=1)
        for item in layout['Rows']:
            x,y,rw,rh=[item[k] for k in ('X','Y','W','H')]
            if rw<=0 or rh<=0: continue
            rect=(int(x),int(y),int(x+rw),int(y+rh))
            layer=Image.new('RGBA',image.size,(0,0,0,0)); ld=ImageDraw.Draw(layer)
            if item['Alpha']>0:
                rgb=tuple(int(item['Fill'][i:i+2],16) for i in (1,3,5))
                ld.rounded_rectangle(rect,radius=item['Radius'],fill=(*rgb,int(item['Alpha']*255)))
            if item['Border']:
                ld.rounded_rectangle(rect,radius=item['Radius'],outline=item['Border'],width=max(1,round(item.get('BorderWidth',1))))
            if item['Text']:
                draw_text(ld,item,x,y,rw,rh)
            if item.get('Rotation'):
                layer=layer.rotate(-item['Rotation'],resample=Image.Resampling.BICUBIC,center=(x+rw/2,y+rh/2))
            for cx,cy,cw,ch,cr in item.get('Clips',[]):
                mask=Image.new('L',image.size,0)
                ImageDraw.Draw(mask).rounded_rectangle((int(cx),int(cy),int(cx+cw),int(cy+ch)),radius=cr,fill=255)
                layer.putalpha(ImageChops.multiply(layer.getchannel('A'),mask))
            image=Image.alpha_composite(image.convert('RGBA'),layer).convert('RGB'); draw=ImageDraw.Draw(image)
        draw.rectangle((0,h,w,h+36),fill=(22,26,33))
        font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',9 if w<500 else 12)
        caption='HUD layout preview · not a Roblox screenshot' if w>=500 else 'HUD layout · not an engine screenshot'
        draw.text((8,h+10),caption,font=font,fill=(157,168,182))
        target=ROOT/'docs'/f'hud-{label}.png'; image.save(target)
        print(target.relative_to(ROOT))


def draw_text(draw,item,x,y,rw,rh):
    font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if item['Bold'] else '')+'.ttf'
    rounded='FredokaOne' in item.get('Font','')
    if rounded and (ROOT/'build/Fredoka.ttf').exists(): font_path=str(ROOT/'build/Fredoka.ttf')
    font=ImageFont.truetype(font_path,max(8,int(item['FontSize'])))
    if rounded and font_path.endswith('Fredoka.ttf'):
        axes=font.get_variation_axes()
        font.set_variation_by_axes([600 if a['name']==b'Weight' else a['default'] for a in axes])
    lines=[]
    for paragraph in item['Text'].splitlines():
        current=''
        for word in paragraph.split():
            candidate=(current+' '+word).strip()
            if current and draw.textlength(candidate,font=font)>rw-4: lines.append(current); current=word
            else: current=candidate
        lines.append(current)
    line_height=math.ceil(item['FontSize']*1.16)
    limit=max(1,int(rh//line_height)); lines=lines[:limit]
    text_y=y+(rh-line_height*len(lines))/2
    for line in lines:
        length=draw.textlength(line,font=font)
        text_x=x+(rw-length)/2 if item['Align'].endswith('Center') else x
        draw.text((text_x,text_y),line,font=font,fill=item['TextColor'],stroke_width=0)
        text_y+=line_height


if __name__=='__main__': main()
