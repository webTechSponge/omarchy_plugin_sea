// Offline artwork preparation, not an application dependency.
// Build: g++ -std=c++17 transparent.cpp -o /tmp/sea-brand $(pkg-config --cflags --libs Qt6Gui)
#include <QImage>
#include <QPainter>
#include <algorithm>
#include <cmath>
#include <cstdio>
#include <vector>
using Mask = std::vector<float>;
static Mask spread(const Mask &in, int w, int h, int radius, bool blur) {
    Mask tmp(in.size()), out(in.size());
    for (int pass=0; pass<2; ++pass) {
        const Mask &src=pass?tmp:in; Mask &dst=pass?out:tmp;
        for(int y=0;y<h;++y) for(int x=0;x<w;++x) {
            float value=0;
            for(int d=-radius;d<=radius;++d) {
                int xx=pass?x:x+d, yy=pass?y+d:y;
                float v=(xx>=0&&xx<w&&yy>=0&&yy<h)?src[yy*w+xx]:0;
                if(blur) value+=v; else value=std::max(value,v);
            }
            dst[y*w+x]=blur?value/(2*radius+1):value;
        }
    }
    return out;
}
int main(int argc,char **argv) {
    if(argc!=3) return 2;
    QImage src(argv[1]); if(src.isNull()) return 1;
    const int w=src.width(),h=src.height(); Mask alpha(w*h);
    QImage foreground(w,h,QImage::Format_ARGB32); foreground.fill(Qt::transparent);
    // The originals have a slightly varying navy matte (roughly RGB 1,13,40).
    // Retain saturated blue shading; only the near-navy matte is keyed out.
    for(int y=0;y<h;++y) for(int x=0;x<w;++x) {
        QColor c=src.pixelColor(x,y);
        float a=std::clamp(std::max({(c.red()-8)/24.f,(c.green()-23)/24.f,(c.blue()-53)/24.f}),0.f,1.f);
        alpha[y*w+x]=a;
        if(a>0) {
            auto unmatte=[a](int v,int bg){return std::clamp(int(std::lround((v-bg*(1-a))/a)),0,255);};
            foreground.setPixelColor(x,y,QColor(unmatte(c.red(),1),unmatte(c.green(),13),unmatte(c.blue(),40),int(a*255)));
        }
    }
    Mask edge=spread(alpha,w,h,4,false);
    Mask shadow=spread(spread(edge,w,h,5,true),w,h,5,true);
    QImage out(w,h,QImage::Format_ARGB32); out.fill(Qt::transparent);
    for(int y=0;y<h;++y) for(int x=0;x<w;++x) {
        float a=std::max(edge[y*w+x]*.72f,shadow[y*w+x]*.35f);
        out.setPixelColor(x,y,QColor(6,20,38,int(a*255)));
    }
    QPainter p(&out); p.drawImage(0,0,foreground); p.end();
    if(!out.save(argv[2])) return 1;
    int clear=0,partial=0;
    for(int y=0;y<h;++y) for(int x=0;x<w;++x) {int a=out.pixelColor(x,y).alpha();clear+=a==0;partial+=a>0&&a<255;}
    printf("%s: RGBA %dx%d; transparent=%d; antialias/shadow=%d\n",argv[2],w,h,clear,partial);
    return clear>0&&partial>0?0:1;
}
