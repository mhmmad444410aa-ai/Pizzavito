package com.godot.game;

import android.app.Activity;
import android.os.SystemClock;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import org.godotengine.godot.Godot;
import org.godotengine.godot.plugin.GodotPlugin;
import org.godotengine.godot.plugin.UsedByGodot;
import com.huawei.hms.ads.*;
import com.huawei.hms.ads.banner.BannerView;

public final class PizzavitoAds extends GodotPlugin {
    private static final String TAG = "PizzavitoAds";
    private static final String BANNER = "c6r9sjkp82";
    private static final String INTERSTITIAL = "i3omws3lj8";
    private BannerView banner;
    private InterstitialAd interstitial;
    private View gameContainer;
    private boolean initialized, wanted, loaded, paused, destroyed, showing;
    private int completed, originalMargin;
    private long lastInterstitial = SystemClock.elapsedRealtime(), lastBannerRequest, lastInterstitialRequest;
    public PizzavitoAds(Godot godot) { super(godot); }
    @Override public String getPluginName() { return "PizzavitoAds"; }

    private AdParam request() {
        return new AdParam.Builder()
          .setTagForChildProtection(TagForChild.TAG_FOR_CHILD_PROTECTION_TRUE)
          .setTagForUnderAgeOfPromise(UnderAge.PROMISE_TRUE)
          .setNonPersonalizedAd(NonPersonalizedAd.ALLOW_NON_PERSONALIZED)
          .setAdContentClassification(ContentClassification.AD_CONTENT_CLASSIFICATION_W)
          .build();
    }
    private boolean initialize() {
        if (initialized) return true;
        Activity a = getActivity();
        if (a == null || a.isFinishing() || destroyed) return false;
        try {
            HwAds.init(a.getApplicationContext());
            HwAds.setRequestOptions(HwAds.getRequestOptions().toBuilder()
              .setTagForChildProtection(TagForChild.TAG_FOR_CHILD_PROTECTION_TRUE)
              .setTagForUnderAgeOfPromise(UnderAge.PROMISE_TRUE)
              .setNonPersonalizedAd(NonPersonalizedAd.ALLOW_NON_PERSONALIZED)
              .setAdContentClassification(ContentClassification.AD_CONTENT_CLASSIFICATION_W).build());
            initialized = true;
            return true;
        } catch (RuntimeException | LinkageError e) { Log.w(TAG,"Ads unavailable",e); return false; }
    }
    private int dp(Activity a,int n) { return Math.round(n*a.getResources().getDisplayMetrics().density); }
    private void updateBanner() {
        if (banner == null || gameContainer == null) return;
        boolean visible = wanted && loaded && !paused && !showing && !destroyed;
        ViewGroup.LayoutParams lp = gameContainer.getLayoutParams();
        if (!(lp instanceof FrameLayout.LayoutParams)) { banner.setVisibility(View.GONE); return; }
        FrameLayout.LayoutParams fl = (FrameLayout.LayoutParams) lp;
        Activity a = getActivity();
        if(a==null) return;
        int desired = originalMargin + (visible ? dp(a,66) : 0);
        if(fl.bottomMargin!=desired) { fl.bottomMargin=desired; gameContainer.setLayoutParams(fl); }
        banner.setVisibility(visible ? View.VISIBLE : View.GONE);
    }
    private void ensureBanner() {
        if (!wanted || paused || destroyed || !initialize()) return;
        Activity a=getActivity();
        if(a==null) return;
        try {
            if(banner==null) {
                View content=a.findViewById(android.R.id.content);
                int id=a.getResources().getIdentifier("godot_fragment_container","id",a.getPackageName());
                View game=a.findViewById(id);
                if (!(content instanceof FrameLayout) || game==null || game.getParent()!=content ||
                    !(game.getLayoutParams() instanceof FrameLayout.LayoutParams)) return;
                if(content.getWidth()>0 && content.getWidth()<dp(a,320)) return;
                gameContainer=game;
                originalMargin=((FrameLayout.LayoutParams)game.getLayoutParams()).bottomMargin;
                banner=new BannerView(a);
                banner.setAdId(BuildConfig.DEBUG ? "testw6vs28auh3" : BANNER);
                banner.setBannerAdSize(BannerAdSize.BANNER_SIZE_320_50);
                banner.setVisibility(View.GONE);
                FrameLayout.LayoutParams p=new FrameLayout.LayoutParams(dp(a,320),dp(a,50),Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL);
                p.bottomMargin=dp(a,8);
                ((FrameLayout)content).addView(banner,p);
                banner.setAdListener(new AdListener(){
                    @Override public void onAdLoaded(){ runOnUiThread(()->{loaded=true;updateBanner();}); }
                    @Override public void onAdFailed(int code){ runOnUiThread(()->{loaded=false;updateBanner();Log.i(TAG,"Banner unavailable: "+code);}); }
                    @Override public void onAdClosed(){ runOnUiThread(()->{loaded=false;updateBanner();}); }
                });
            }
            long now=SystemClock.elapsedRealtime();
            if(!loaded && (lastBannerRequest==0 || now-lastBannerRequest>=60000)){
                lastBannerRequest=now; banner.loadAd(request());
            }
            updateBanner();
        } catch(RuntimeException | LinkageError e){ loaded=false;updateBanner();Log.w(TAG,"Banner unavailable",e); }
    }
    private void preload() {
        if(paused || destroyed || !initialize()) return;
        Activity a=getActivity(); if(a==null) return;
        try {
            if(interstitial==null){
                interstitial=new InterstitialAd(a);
                interstitial.setAdId(BuildConfig.DEBUG ? "teste9ih9j0rc3" : INTERSTITIAL);
                interstitial.setAdListener(new AdListener(){
                    @Override public void onAdClosed(){runOnUiThread(()->{showing=false;interstitial=null;updateBanner();});}
                    @Override public void onAdFailed(int code){Log.i(TAG,"Interstitial unavailable: "+code);}
                });
            }
            long now=SystemClock.elapsedRealtime();
            if(!interstitial.isLoaded() && !interstitial.isLoading() && (lastInterstitialRequest==0 || now-lastInterstitialRequest>=60000)){
                lastInterstitialRequest=now;interstitial.loadAd(request());
            }
        } catch(RuntimeException | LinkageError e){Log.w(TAG,"Interstitial unavailable",e);}
    }
    @UsedByGodot public void setScreen(String screen) {
        runOnUiThread(()->{
            wanted="home".equals(screen)||"cook".equals(screen);
            if(wanted){ensureBanner();preload();} else updateBanner();
        });
    }
    @UsedByGodot public void recipeCompleted(){
        runOnUiThread(()->{
            completed++;
            long now=SystemClock.elapsedRealtime();
            Activity a=getActivity();
            if(a==null||paused||destroyed||showing||wanted) return;
            try{
                if(completed>=3 && now-lastInterstitial>=120000 && interstitial!=null && interstitial.isLoaded()){
                    completed=0;lastInterstitial=now;showing=true;updateBanner();interstitial.show(a);
                } else preload();
            } catch(RuntimeException | LinkageError e){showing=false;updateBanner();Log.w(TAG,"Ad skipped",e);}
        });
    }
    @Override public void onMainPause(){runOnUiThread(()->{paused=true;updateBanner();if(banner!=null)banner.pause();});}
    @Override public void onMainResume(){runOnUiThread(()->{paused=false;if(banner!=null)banner.resume();if(wanted)ensureBanner();});}
    @Override public void onMainDestroy(){runOnUiThread(()->{
        destroyed=true;wanted=false;updateBanner();
        if(banner!=null){if(banner.getParent() instanceof ViewGroup)((ViewGroup)banner.getParent()).removeView(banner);banner.destroy();banner=null;}
        interstitial=null;gameContainer=null;
    });}
}
