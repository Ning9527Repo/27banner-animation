#pragma once
#include <math.h>
#include <stddef.h>
/* Reconstructed from GlassSuiteX 1.1-0, arm64e VA 0x6eb68.
 * Channels: scale.x, scale.y, normalized position.x, normalized position.y.
 * Sampler VA 0x40e48; keyframe builder VA 0x41064. Not a fitted spring. */
static const double NB27Duration = 0.86;
static const size_t NB27SampleCount = 217;
static const double NB27MotionNodes[16][5] = {
 {0.00,.110,.115,-.372,-.620}, {0.04,.110,.115,-.372,-.470},
 {0.08,.110,.115,-.372,-.190}, {0.12,.112,.120,-.371,.070},
 {0.15,.147,.245,-.348,.220}, {0.19,.239,.435,-.284,.280},
 {0.23,.343,.670,-.220,.272}, {0.27,.455,.873,-.152,.217},
 {0.31,.563,1.020,-.096,.154}, {0.35,.660,1.090,-.056,.085},
 {0.40,.767,1.105,-.023,.028}, {0.48,.889,1.075,.003,-.012},
 {0.57,.963,1.025,.013,-.012}, {0.66,.991,1.006,.009,-.005},
 {0.76,1.000,1.000,.001,.000}, {0.86,1.000,1.000,.000,.000}
};
static inline double NB27Clamp(double x,double a,double b) { return fmin(fmax(x,a),b); }
static inline double NB27Slope(size_t i,unsigned c) {
 if (i==0 || i==15) return 0;
 double h0=NB27MotionNodes[i][0]-NB27MotionNodes[i-1][0];
 double h1=NB27MotionNodes[i+1][0]-NB27MotionNodes[i][0];
 double d0=(NB27MotionNodes[i][c+1]-NB27MotionNodes[i-1][c+1])/h0;
 double d1=(NB27MotionNodes[i+1][c+1]-NB27MotionNodes[i][c+1])/h1;
 if (d0*d1<=0) return 0;
 double w0=2*h1+h0,w1=2*h0+h1;
 return (w0+w1)/(w0/d0+w1/d1);
}
static inline double NB27Motion(double t,unsigned c) {
 if (c>3 || !isfinite(t)) return c<2?1:0;
 if (t<=0) return NB27MotionNodes[0][c+1];
 if (t>=NB27Duration) return NB27MotionNodes[15][c+1];
 size_t i=0; while (i<14 && t>NB27MotionNodes[i+1][0]) ++i;
 double h=NB27MotionNodes[i+1][0]-NB27MotionNodes[i][0];
 double u=(t-NB27MotionNodes[i][0])/h,u2=u*u,u3=u2*u;
 return (2*u3-3*u2+1)*NB27MotionNodes[i][c+1]
      +(u3-2*u2+u)*h*NB27Slope(i,c)
      +(-2*u3+3*u2)*NB27MotionNodes[i+1][c+1]
      +(u3-u2)*h*NB27Slope(i+1,c);
}
static inline double NB27ExitDuration(double nativeDuration,double motionTime) {
 double safeDuration=isfinite(nativeDuration)&&nativeDuration>0?nativeDuration:1.0/60.0;
 double cap=fmin(fmax(safeDuration-1.0/60.0,safeDuration*.5),.48);
 double fraction=isfinite(motionTime)?NB27Clamp(motionTime/NB27Duration,.25,1):.25;
 return fmin(cap*fraction,safeDuration*.9);
}
/* Original exit opacity helper: 1 until 0.8, then quintic smoothstep. */
static inline double NB27ExitOpacity(double p) {
 if(p<=.8) return 1;
 if(p>=1) return 0;
 double u=NB27Clamp((p-.8)/.2,0,1);
 return NB27Clamp(1-u*u*u*(10+u*(-15+6*u)),0,1);
}
