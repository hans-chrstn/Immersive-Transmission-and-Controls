module ImmersiveTransmission.UI

public class ITC_HUDComponent extends inkComponent {
  private let frameBg: ref<inkImage>;
  private let frameBorder: ref<inkImage>;
  private let modeText: ref<inkText>;
  private let gearText: ref<inkText>;
  private let speedText: ref<inkText>;
  
  // RPM Elements
  private let rpmBarBg: ref<inkRectangle>;
  private let rpmBarFill: ref<inkRectangle>;
  private let rpmText: ref<inkText>;

  // Status Badges
  private let engText: ref<inkText>;
  private let hbText: ref<inkText>;
  private let ccText: ref<inkText>;
  private let diffText: ref<inkText>;
  private let clText: ref<inkText>;
  private let brkText: ref<inkText>;

  protected cb func OnCreate() -> ref<inkWidget> {
    let canvas = new inkCanvas();
    canvas.SetName(n"ITC_HUD_Canvas");
    canvas.SetSize(new Vector2(280.0, 160.0));
    canvas.SetInteractive(false);

    // 1. Native Cyber Panel Background
    let bg = new inkImage();
    bg.SetName(n"ITC_HUD_Bg");
    bg.SetSize(new Vector2(280.0, 160.0));
    bg.SetAtlasResource(r"ep1\\gameplay\\gui\\world\\computers\\computer_oa.inkatlas");
    bg.SetTexturePart(n"frame_big_bg");
    let bgColor: HDRColor; bgColor.Red = 0.05; bgColor.Green = 0.05; bgColor.Blue = 0.07; bgColor.Alpha = 0.85;
    bg.SetTintColor(bgColor);
    bg.Reparent(canvas);
    this.frameBg = bg;

    // 2. Native Cyber Panel Border Outline
    let border = new inkImage();
    border.SetName(n"ITC_HUD_Border");
    border.SetSize(new Vector2(280.0, 160.0));
    border.SetAtlasResource(r"ep1\\gameplay\\gui\\world\\computers\\computer_oa.inkatlas");
    border.SetTexturePart(n"frame_big");
    border.SetTintColor(this.GetColorBlue());
    border.Reparent(canvas);
    this.frameBorder = border;

    // 3. Transmission Mode (Top Left)
    let modeTxt = new inkText();
    modeTxt.SetName(n"ITC_HUD_Mode");
    modeTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    modeTxt.SetFontStyle(n"Medium");
    modeTxt.SetFontSize(12);
    modeTxt.SetTranslation(new Vector2(20.0, 15.0));
    modeTxt.Reparent(canvas);
    this.modeText = modeTxt;

    // 4. Engine Status (Top Right)
    let engTxt = new inkText();
    engTxt.SetName(n"ITC_HUD_Eng");
    engTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    engTxt.SetFontStyle(n"Medium");
    engTxt.SetFontSize(12);
    engTxt.SetTranslation(new Vector2(200.0, 15.0));
    engTxt.Reparent(canvas);
    this.engText = engTxt;

    // 5. Gear Indicator (Center Left)
    let gearTxt = new inkText();
    gearTxt.SetName(n"ITC_HUD_Gear");
    gearTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    gearTxt.SetFontStyle(n"Bold");
    gearTxt.SetFontSize(38);
    gearTxt.SetTranslation(new Vector2(20.0, 32.0));
    gearTxt.Reparent(canvas);
    this.gearText = gearTxt;

    // 6. Speedometer Value (Center)
    let spdTxt = new inkText();
    spdTxt.SetName(n"ITC_HUD_Speed");
    spdTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    spdTxt.SetFontStyle(n"Bold");
    spdTxt.SetFontSize(30);
    spdTxt.SetTranslation(new Vector2(90.0, 36.0));
    spdTxt.Reparent(canvas);
    this.speedText = spdTxt;

    // 7. RPM Bar Background Track (Lower Center)
    let rpmBg = new inkRectangle();
    rpmBg.SetName(n"ITC_HUD_RPM_Bg");
    rpmBg.SetSize(new Vector2(180.0, 6.0));
    rpmBg.SetTranslation(new Vector2(20.0, 92.0));
    let trackColor: HDRColor; trackColor.Red = 0.15; trackColor.Green = 0.15; trackColor.Blue = 0.2; trackColor.Alpha = 0.5;
    rpmBg.SetTintColor(trackColor);
    rpmBg.Reparent(canvas);
    this.rpmBarBg = rpmBg;

    // 8. RPM Bar Filling (Lower Center)
    let rpmFill = new inkRectangle();
    rpmFill.SetName(n"ITC_HUD_RPM_Fill");
    rpmFill.SetSize(new Vector2(0.0, 6.0)); // Initialized at 0 width
    rpmFill.SetTranslation(new Vector2(20.0, 92.0));
    rpmFill.SetTintColor(this.GetColorBlue());
    rpmFill.Reparent(canvas);
    this.rpmBarFill = rpmFill;

    // 9. RPM Text Value (Lower Right)
    let rpmTxt = new inkText();
    rpmTxt.SetName(n"ITC_HUD_RPM_Val");
    rpmTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    rpmTxt.SetFontStyle(n"Medium");
    rpmTxt.SetFontSize(13);
    rpmTxt.SetTranslation(new Vector2(210.0, 86.0));
    rpmTxt.Reparent(canvas);
    this.rpmText = rpmTxt;

    // 10. Status Badges Row (Bottom)
    let hbTxt = new inkText();
    hbTxt.SetName(n"ITC_HUD_HB");
    hbTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    hbTxt.SetFontStyle(n"Regular");
    hbTxt.SetFontSize(11);
    hbTxt.SetTranslation(new Vector2(20.0, 120.0));
    hbTxt.Reparent(canvas);
    this.hbText = hbTxt;

    let ccTxt = new inkText();
    ccTxt.SetName(n"ITC_HUD_CC");
    ccTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    ccTxt.SetFontStyle(n"Regular");
    ccTxt.SetFontSize(11);
    ccTxt.SetTranslation(new Vector2(90.0, 120.0));
    ccTxt.Reparent(canvas);
    this.ccText = ccTxt;

    let diffTxt = new inkText();
    diffTxt.SetName(n"ITC_HUD_Diff");
    diffTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    diffTxt.SetFontStyle(n"Regular");
    diffTxt.SetFontSize(11);
    diffTxt.SetTranslation(new Vector2(170.0, 120.0));
    diffTxt.Reparent(canvas);
    this.diffText = diffTxt;

    // Debug Foot Pedal Indicators
    let clTxt = new inkText();
    clTxt.SetName(n"ITC_HUD_CL");
    clTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    clTxt.SetFontStyle(n"Regular");
    clTxt.SetFontSize(11);
    clTxt.SetTranslation(new Vector2(20.0, 138.0));
    clTxt.Reparent(canvas);
    this.clText = clTxt;

    let brkTxt = new inkText();
    brkTxt.SetName(n"ITC_HUD_BRK");
    brkTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    brkTxt.SetFontStyle(n"Regular");
    brkTxt.SetFontSize(11);
    brkTxt.SetTranslation(new Vector2(110.0, 138.0));
    brkTxt.Reparent(canvas);
    this.brkText = brkTxt;

    return canvas;
  }

  public func Update(vis: Int32, mounted: Int32, mode: Int32, gear: Int32, diff: Int32, brake: Int32, clutch: Int32, footBrake: Int32, cc: Int32, engine: Int32, speed: Int32, rpmPercent: Int32, rpmRaw: Int32, posX: Int32, posY: Int32) {
    let canvas = this.GetRootWidget();
    if !IsDefined(canvas) {
      LogChannel(n"DEBUG", "ITC HUD: Update() - root canvas widget is null!");
      return;
    }

    canvas.SetVisible(vis == 1);
    if vis != 1 { return; }

    let fracX: Float = Cast<Float>(posX) / 100.0;
    let fracY: Float = Cast<Float>(posY) / 100.0;
    // Map to native 1920x1080 virtual window coordinate system
    canvas.SetTranslation(new Vector2(1920.0 * fracX, 1080.0 * fracY));

    // Transmission Mode
    let modeTxtStr: String = "AUTOMATIC";
    let modeColor: HDRColor = this.GetColorBlue();
    if mode == 1 {
      modeTxtStr = "MANUAL";
      modeColor = this.GetColorYellow();
    } else if mode == 2 {
      modeTxtStr = "AUTO OVERRIDE";
      modeColor = this.GetColorOrange();
    }
    if mounted != 1 {
      modeTxtStr = "UNMOUNTED";
    }
    this.modeText.SetText(modeTxtStr);
    this.modeText.SetTintColor(modeColor);

    // Engine Status
    if engine == 1 {
      this.engText.SetText("ENG: ON");
      this.engText.SetTintColor(this.GetColorGreen());
    } else {
      this.engText.SetText("ENG: OFF");
      this.engText.SetTintColor(this.GetColorDim());
    }

    // Gear display
    let gearStr: String = "";
    let gearColor: HDRColor = this.GetColorYellow();
    if gear == 0 {
      gearStr = "R";
      gearColor = this.GetColorRed();
    } else if gear == 1 {
      gearStr = "N";
      gearColor = this.GetColorGrey();
    } else if gear >= 200 {
      gearStr = "M" + IntToString(gear - 200);
    } else if gear >= 100 {
      gearStr = "D" + IntToString(gear - 100);
    } else {
      gearStr = IntToString(gear - 1);
    }
    this.gearText.SetText(gearStr);
    this.gearText.SetTintColor(gearColor);

    // Speed display
    this.speedText.SetText(IntToString(speed) + " km/h");
    this.speedText.SetTintColor(this.GetColorBlue());

    // RPM Bar and text update
    let fillWidth: Float = (Cast<Float>(rpmPercent) / 100.0) * 180.0;
    if fillWidth < 0.0 { fillWidth = 0.0; }
    if fillWidth > 180.0 { fillWidth = 180.0; }
    this.rpmBarFill.SetSize(new Vector2(fillWidth, 6.0));

    // Shift RPM colors
    let barColor: HDRColor;
    if rpmPercent >= 85 {
      barColor = this.GetColorRed();
    } else if rpmPercent >= 60 {
      barColor = this.GetColorYellow();
    } else {
      barColor = this.GetColorBlue();
    }
    this.rpmBarFill.SetTintColor(barColor);
    this.rpmText.SetText(IntToString(rpmRaw) + " RPM");
    this.rpmText.SetTintColor(barColor);

    // Status Badges
    if brake == 1 {
      this.hbText.SetText("HB: ON");
      this.hbText.SetTintColor(this.GetColorRed());
    } else {
      this.hbText.SetText("HB: OFF");
      this.hbText.SetTintColor(this.GetColorDim());
    }

    if cc == 1 {
      this.ccText.SetText("CC: ON");
      this.ccText.SetTintColor(this.GetColorGreen());
    } else {
      this.ccText.SetText("CC: OFF");
      this.ccText.SetTintColor(this.GetColorDim());
    }

    if diff == 1 {
      this.diffText.SetText("DIFF: ON");
      this.diffText.SetTintColor(this.GetColorOrange());
    } else {
      this.diffText.SetText("DIFF: OFF");
      this.diffText.SetTintColor(this.GetColorDim());
    }

    // Pedals
    if clutch == 1 {
      this.clText.SetText("CL: ON");
      this.clText.SetTintColor(this.GetColorYellow());
    } else {
      this.clText.SetText("CL: OFF");
      this.clText.SetTintColor(this.GetColorDim());
    }

    if footBrake == 1 {
      this.brkText.SetText("BRK: ON");
      this.brkText.SetTintColor(this.GetColorRed());
    } else {
      this.brkText.SetText("BRK: OFF");
      this.brkText.SetTintColor(this.GetColorDim());
    }
  }

  private func GetColorBlue() -> HDRColor {
    let c: HDRColor; c.Red = 0.35; c.Green = 0.75; c.Blue = 1.0; c.Alpha = 1.0;
    return c;
  }
  private func GetColorYellow() -> HDRColor {
    let c: HDRColor; c.Red = 1.0; c.Green = 0.85; c.Blue = 0.15; c.Alpha = 1.0;
    return c;
  }
  private func GetColorOrange() -> HDRColor {
    let c: HDRColor; c.Red = 1.0; c.Green = 0.55; c.Blue = 0.0; c.Alpha = 1.0;
    return c;
  }
  private func GetColorRed() -> HDRColor {
    let c: HDRColor; c.Red = 1.0; c.Green = 0.2; c.Blue = 0.2; c.Alpha = 1.0;
    return c;
  }
  private func GetColorGrey() -> HDRColor {
    let c: HDRColor; c.Red = 0.6; c.Green = 0.6; c.Blue = 0.6; c.Alpha = 1.0;
    return c;
  }
  private func GetColorGreen() -> HDRColor {
    let c: HDRColor; c.Red = 0.2; c.Green = 0.9; c.Blue = 0.2; c.Alpha = 1.0;
    return c;
  }
  private func GetColorDim() -> HDRColor {
    let c: HDRColor; c.Red = 0.25; c.Green = 0.25; c.Blue = 0.28; c.Alpha = 0.5;
    return c;
  }
}

public class ITC_HUD extends IScriptable {
  private let comp: ref<ITC_HUDComponent>;

  public func Ensure() -> Void {
    let inkSys: ref<inkSystem> = GameInstance.GetInkSystem();
    if !IsDefined(inkSys) {
      LogChannel(n"DEBUG", "ITC HUD: Ensure() - inkSystem is null");
      return;
    }
    let hudLayer = inkSys.GetLayer(n"inkHUDLayer");
    if !IsDefined(hudLayer) {
      LogChannel(n"DEBUG", "ITC HUD: Ensure() - inkHUDLayer is null");
      return;
    }
    let vwin = hudLayer.GetVirtualWindow();
    if !IsDefined(vwin) {
      LogChannel(n"DEBUG", "ITC HUD: Ensure() - virtualWindow is null");
      return;
    }

    let existingCanvas = vwin.GetWidgetByPathName(n"ITC_HUD_Canvas");
    if IsDefined(existingCanvas) {
      LogChannel(n"DEBUG", "ITC HUD: Ensure() - Found existing canvas widget.");
      this.comp = existingCanvas.GetController() as ITC_HUDComponent;
      if !IsDefined(this.comp) {
        LogChannel(n"DEBUG", "ITC HUD: Ensure() - Controller is null or not ITC_HUDComponent! Removing old widget.");
        vwin.RemoveChild(existingCanvas);
        existingCanvas = null;
      } else {
        LogChannel(n"DEBUG", "ITC HUD: Ensure() - Controller cast succeeded.");
      }
    }
    if !IsDefined(existingCanvas) {
      this.comp = new ITC_HUDComponent();
      this.comp.Reparent(vwin);
      LogChannel(n"DEBUG", "ITC HUD: Component successfully instantiated and parented to vwin.");
    }
  }

  public func Refresh() -> Void {
    this.Ensure();
    if !IsDefined(this.comp) {
      LogChannel(n"DEBUG", "ITC HUD: Refresh() - comp is null, returning early");
      return;
    }

    let qs = GameInstance.GetQuestsSystem(GetGameInstance());
    if !IsDefined(qs) {
      LogChannel(n"DEBUG", "ITC HUD: Refresh() - QuestSystem is null, returning early");
      return;
    }

    let vis: Int32 = qs.GetFact(n"itc_hud_visible");
    let mounted: Int32 = qs.GetFact(n"itc_hud_mounted");
    let mode: Int32 = qs.GetFact(n"itc_hud_mode");
    let gear: Int32 = qs.GetFact(n"itc_hud_gear");
    let diff: Int32 = qs.GetFact(n"itc_hud_diff");
    let brake: Int32 = qs.GetFact(n"itc_hud_handbrake");
    let clutch: Int32 = qs.GetFact(n"itc_hud_clutch");
    let footBrake: Int32 = qs.GetFact(n"itc_hud_brake");
    let cc: Int32 = qs.GetFact(n"itc_hud_cc");
    let engine: Int32 = qs.GetFact(n"itc_hud_engine");
    let speed: Int32 = qs.GetFact(n"itc_hud_speed");
    let rpmPercent: Int32 = qs.GetFact(n"itc_hud_rpm");
    let rpmRaw: Int32 = qs.GetFact(n"itc_hud_rpm_raw");
    let posX: Int32 = qs.GetFact(n"itc_hud_pos_x");
    let posY: Int32 = qs.GetFact(n"itc_hud_pos_y");

    if posX <= 0 { posX = 85; }
    if posY <= 0 { posY = 82; }

    LogChannel(n"DEBUG", "ITC HUD: Refresh() - calling Update with facts: vis=" + IntToString(vis) + " mounted=" + IntToString(mounted) + " mode=" + IntToString(mode) + " gear=" + IntToString(gear) + " engine=" + IntToString(engine));

    this.comp.Update(vis, mounted, mode, gear, diff, brake, clutch, footBrake, cc, engine, speed, rpmPercent, rpmRaw, posX, posY);
  }
}

@addField(UISystem)
public let itcHUD: ref<ITC_HUD>;

@wrapMethod(UISystem)
public final func PushGameContext(context: UIGameContext) -> Void {
  wrappedMethod(context);
  if !IsDefined(this.itcHUD) { this.itcHUD = new ITC_HUD(); }
  this.itcHUD.Refresh();
}

@wrapMethod(UISystem)
public final func PopGameContext(context: UIGameContext, opt invalidate: Bool) -> Void {
  wrappedMethod(context, invalidate);
  if !IsDefined(this.itcHUD) { this.itcHUD = new ITC_HUD(); }
  this.itcHUD.Refresh();
}

@wrapMethod(PlayerPuppet)
protected cb func OnTakeControl(resolver: EntityResolveComponentsInterface) -> Bool {
  let r = wrappedMethod(resolver);
  let uiSys: ref<UISystem> = GameInstance.GetUISystem(GetGameInstance());
  if IsDefined(uiSys) {
    if !IsDefined(uiSys.itcHUD) { uiSys.itcHUD = new ITC_HUD(); }
    uiSys.itcHUD.Refresh();
  }
  return r;
}
