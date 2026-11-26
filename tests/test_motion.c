#include <assert.h>
#include <stdio.h>
#include "../Sources/NB27Motion.h"
static void closeEnough(double x,double y) { assert(isfinite(x)&&fabs(x-y)<1e-10); }
int main(void) {
 unsigned long cases=0;
 for(unsigned c=0;c<4;c++) {
  for(size_t i=0;i<16;i++) {closeEnough(NB27Motion(NB27MotionNodes[i][0],c),NB27MotionNodes[i][c+1]);cases++;}
  for(size_t i=0;i<15;i++)for(size_t j=0;j<=1000;j++) {
   double t=NB27MotionNodes[i][0]+(NB27MotionNodes[i+1][0]-NB27MotionNodes[i][0])*j/1000;
   double lo=fmin(NB27MotionNodes[i][c+1],NB27MotionNodes[i+1][c+1]);
   double hi=fmax(NB27MotionNodes[i][c+1],NB27MotionNodes[i+1][c+1]);
   double v=NB27Motion(t,c);assert(isfinite(v)&&v>=lo-1e-12&&v<=hi+1e-12);cases++;
  }
 }
 assert(NB27SampleCount==217);closeEnough(NB27Duration,.86);
 for(size_t i=0;i<NB27SampleCount;i++) {
  double p=(double)i/(NB27SampleCount-1),a=NB27ExitOpacity(p);
  assert(a>=0&&a<=1);if(p<=.8)closeEnough(a,1);cases++;
 }
 closeEnough(NB27ExitOpacity(1),0);closeEnough(NB27ExitOpacity(.8),1);
 closeEnough(NB27ExitOpacity(.9),.5);
 for(unsigned width=100;width<=500;width+=10)for(unsigned anchor=0;anchor<=10;anchor++)
 for(unsigned sample=0;sample<217;sample++) {
  double t=.86*sample/216,x=NB27Motion(t,0)-1,delta=width*NB27Motion(t,2);
  double px=fma(x,width*(anchor/10.0-.5),delta);
  double rtl=fma(x,width*((1-anchor/10.0)-.5),-delta);
  closeEnough(px,-rtl);assert(isfinite(px));cases++;
 }
 for(unsigned ms=1;ms<=1000;ms++)for(unsigned i=0;i<217;i++) {
  double native=ms/1000.0,start=.86*i/216,duration=NB27ExitDuration(native,start);
  assert(isfinite(duration)&&duration>0&&duration<native);cases++;
  for(unsigned c=0;c<4;c++)closeEnough(NB27Motion(start,c)-NB27Motion(start,c),0);
 }
 closeEnough(NB27ExitDuration(NAN,.4),NB27ExitDuration(1.0/60.0,.4));
 closeEnough(NB27ExitDuration(0,.4),NB27ExitDuration(1.0/60.0,.4));
 cases+=2;
 printf("PASS: %lu production motion/geometry assertions; no UIKit runtime claim\n",cases);
 return 0;
}
