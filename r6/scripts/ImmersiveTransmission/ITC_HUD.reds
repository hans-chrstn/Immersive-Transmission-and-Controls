module ImmersiveTransmission.UI



public class ITC_HUDComponent extends inkComponent {
  private let modeText: ref<inkText>;
  private let gearText: ref<inkText>;
  private let statusText: ref<inkText>;
  private let testText: ref<inkText>;

  protected cb func OnCreate() -> ref<inkWidget> {
    let canvas = new inkCanvas();
    canvas.SetName(n"ITC_HUD_Canvas");
    canvas.SetSize(new Vector2(250.0, 130.0));
    canvas.SetInteractive(false);

    let modeTxt = new inkText();
    modeTxt.SetName(n"ITC_HUD_Mode");
    modeTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    modeTxt.SetFontStyle(n"Medium");
    modeTxt.SetFontSize(14);
    modeTxt.SetFitToContent(true);
    modeTxt.SetLetterCase(textLetterCase.OriginalCase);
    modeTxt.SetTranslation(new Vector2(15.0, 8.0));
    modeTxt.Reparent(canvas);
    this.modeText = modeTxt;

    let gearTxt = new inkText();
    gearTxt.SetName(n"ITC_HUD_Gear");
    gearTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    gearTxt.SetFontStyle(n"Bold");
    gearTxt.SetFontSize(42);
    gearTxt.SetFitToContent(true);
    gearTxt.SetLetterCase(textLetterCase.OriginalCase);
    gearTxt.SetTranslation(new Vector2(15.0, 20.0));
    gearTxt.Reparent(canvas);
    this.gearText = gearTxt;

    let statusTxt = new inkText();
    statusTxt.SetName(n"ITC_HUD_Status");
    statusTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    statusTxt.SetFontStyle(n"Regular");
    statusTxt.SetFontSize(13);
    statusTxt.SetFitToContent(true);
    statusTxt.SetLetterCase(textLetterCase.OriginalCase);
    statusTxt.SetTranslation(new Vector2(15.0, 75.0));
    statusTxt.Reparent(canvas);
    this.statusText = statusTxt;

    let testTxt = new inkText();
    testTxt.SetName(n"ITC_HUD_Test");
    testTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    testTxt.SetFontStyle(n"Bold");
    testTxt.SetFontSize(14);
    testTxt.SetText("ITC HUD ACTIVE");
    let greenColor: HDRColor; greenColor.Red = 0.0; greenColor.Green = 1.0; greenColor.Blue = 0.0; greenColor.Alpha = 1.0;
    testTxt.SetTintColor(greenColor);
    testTxt.SetTranslation(new Vector2(15.0, 98.0));
    testTxt.Reparent(canvas);
    this.testText = testTxt;

    return canvas;
  }

  public func Update(vis: Int32, mounted: Int32, mode: Int32, gear: Int32, diff: Int32, brake: Int32, clutch: Int32, footBrake: Int32, cc: Int32, engine: Int32, posX: Int32, posY: Int32) {
    let canvas = this.GetRootWidget();
    if !IsDefined(canvas) {
      LogChannel(n"DEBUG", "ITC HUD: Update() - root canvas widget is null!");
      return;
    }

    LogChannel(n"DEBUG", "ITC HUD: Update() - updating visibility: " + IntToString(vis));

    canvas.SetVisible(vis == 1);
    if vis != 1 { return; }

    let fracX: Float = Cast<Float>(posX) / 100.0;
    let fracY: Float = Cast<Float>(posY) / 100.0;
    // Map to native 1920x1080 virtual window coordinate system
    canvas.SetTranslation(new Vector2(1920.0 * fracX, 1080.0 * fracY));

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

    let statusStr: String = "";
    statusStr = statusStr + (engine == 1 ? "ENG: ON" : "ENG: OFF");
    statusStr = statusStr + (brake == 1 ? " | HB" : "");
    statusStr = statusStr + (cc == 1 ? " | CC" : "");
    statusStr = statusStr + (diff == 1 ? " | DIFF" : "");
    this.statusText.SetText(statusStr);

    let testStr: String = "";
    testStr = testStr + (clutch == 1 ? "CL: ON" : "CL: OFF");
    testStr = testStr + (footBrake == 1 ? " | BRK: ON" : " | BRK: OFF");
    this.testText.SetText(testStr);
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
    let posX: Int32 = qs.GetFact(n"itc_hud_pos_x");
    let posY: Int32 = qs.GetFact(n"itc_hud_pos_y");

    if posX <= 0 { posX = 85; }
    if posY <= 0 { posY = 82; }

    LogChannel(n"DEBUG", "ITC HUD: Refresh() - calling Update with facts: vis=" + IntToString(vis) + " mounted=" + IntToString(mounted) + " mode=" + IntToString(mode) + " gear=" + IntToString(gear) + " engine=" + IntToString(engine));

    this.comp.Update(vis, mounted, mode, gear, diff, brake, clutch, footBrake, cc, engine, posX, posY);
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
