#!/usr/bin/env python3
"""Optional documentation preview from real GUI contract geometry, not an engine screenshot.

Requires Pillow, which is not required to build/test the game.
"""
from pathlib import Path
import json
import math
from PIL import Image, ImageDraw, ImageFont

ROOT=Path(__file__).resolve().parents[1]


def main():
    for width,label in [(320,'phone'),(1280,'desktop')]:
        layout=json.loads((ROOT/'build'/f'ui-layout-{width}.json').read_text())
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
            if item['Alpha']>0:
                layer=Image.new('RGBA',image.size,(0,0,0,0)); ld=ImageDraw.Draw(layer)
                rgb=tuple(int(item['Fill'][i:i+2],16) for i in (1,3,5))
                ld.rounded_rectangle(rect,radius=item['Radius'],fill=(*rgb,int(item['Alpha']*255)))
                image=Image.alpha_composite(image.convert('RGBA'),layer).convert('RGB'); draw=ImageDraw.Draw(image)
            if item['Border']:
                draw.rounded_rectangle(rect,radius=item['Radius'],outline=item['Border'],width=1)
            if not item['Text']: continue
            font_path='/usr/share/fonts/truetype/dejavu/DejaVuSans'+('-Bold' if item['Bold'] else '')+'.ttf'
            font=ImageFont.truetype(font_path,max(8,int(item['FontSize'])))
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
        draw.rectangle((0,h,w,h+36),fill=(22,26,33))
        font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',9 if w<500 else 12)
        caption='HUD layout preview · not a Roblox screenshot' if w>=500 else 'HUD layout · not an engine screenshot'
        draw.text((8,h+10),caption,font=font,fill=(157,168,182))
        target=ROOT/'docs'/f'hud-{label}.png'; image.save(target)
        print(target.relative_to(ROOT))


if __name__=='__main__': main()
