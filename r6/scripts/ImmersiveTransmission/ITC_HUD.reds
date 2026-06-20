module ImmersiveTransmission.UI

public class ITC_HUDTick extends DelayCallback {
  private let hud: wref<ITC_HUD>;

  public func Call() -> Void {
    if IsDefined(this.hud) {
      this.hud.__tickArmed = false;
      this.hud.Refresh();
      this.hud.ArmNextTick();
    }
  }

  public static func Create(h: ref<ITC_HUD>) -> ref<ITC_HUDTick> {
    let t = new ITC_HUDTick();
    t.hud = h;
    return t;
  }
}

public class ITC_HUD extends IScriptable {

  private let tick: ref<ITC_HUDTick>;
  private let tickPeriod: Float = 0.1;
  public let __tickArmed: Bool;

  private let __built: Bool;

  private let rootCanvas: ref<inkCanvas>;
  private let backgroundCard: ref<inkRectangle>;
  private let modeText: ref<inkText>;
  private let gearText: ref<inkText>;
  private let statusText: ref<inkText>;

  private let __dirty: Bool = true;
  private let lastMode: Int32;
  private let lastGear: Int32;
  private let lastDiff: Int32;
  private let lastBrake: Int32;
  private let lastVisible: Int32;
  private let lastClutch: Int32;
  private let lastFootBrake: Int32;

  private func RootExists(rootNode: ref<inkCompoundWidget>) -> Bool {
    if !IsDefined(rootNode) { return false; }
    let canvas: ref<inkCanvas> = rootNode.GetWidget(n"ITC_HUD_Canvas") as inkCanvas;
    return IsDefined(canvas);
  }

  public func Ensure() -> Void {
    let inkSys: ref<inkSystem> = GameInstance.GetInkSystem();
    if !IsDefined(inkSys) {
      this.ArmNextTick();
      return;
    }
    let hudLayer = inkSys.GetLayer(n"inkHUDLayer");
    if !IsDefined(hudLayer) {
      this.ArmNextTick();
      return;
    }
    let vwin: ref<inkCompoundWidget> = hudLayer.GetVirtualWindow();
    if !IsDefined(vwin) {
      this.ArmNextTick();
      return;
    }

    let rootNode = vwin.GetWidgetByPathName(n"Root") as inkCompoundWidget;
    if !IsDefined(rootNode) {
      this.ArmNextTick();
      return;
    }

    if this.__built && !this.RootExists(rootNode) {
      LogChannel(n"DEBUG", "ITC HUD: RootExists returned false. Resetting built state.");
      this.__built = false;
      this.__dirty = true;
    }

    if !this.__built {
      LogChannel(n"DEBUG", "ITC HUD: Rebuilding widgets...");
      let canvas: ref<inkCanvas> = rootNode.GetWidget(n"ITC_HUD_Canvas") as inkCanvas;
      if !IsDefined(canvas) {
        canvas = new inkCanvas();
        canvas.SetName(n"ITC_HUD_Canvas");
        canvas.SetSize(new Vector2(250.0, 150.0));
        canvas.SetInteractive(false);
        canvas.Reparent(rootNode);
      }
      this.rootCanvas = canvas;

      let bg: ref<inkRectangle> = canvas.GetWidget(n"ITC_HUD_BG") as inkRectangle;
      if !IsDefined(bg) {
        bg = new inkRectangle();
        bg.SetName(n"ITC_HUD_BG");
        bg.SetSize(new Vector2(160.0, 95.0));
        let darkColor: HDRColor;
        darkColor.Red = 0.03; darkColor.Green = 0.03; darkColor.Blue = 0.03; darkColor.Alpha = 0.8;
        bg.SetTintColor(darkColor);
        bg.Reparent(canvas);
      }
      this.backgroundCard = bg;

      let modeTxt: ref<inkText> = canvas.GetWidget(n"ITC_HUD_Mode") as inkText;
      if !IsDefined(modeTxt) {
        LogChannel(n"DEBUG", "ITC HUD: Creating Mode text widget");
        modeTxt = new inkText();
        modeTxt.SetName(n"ITC_HUD_Mode");
        modeTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        modeTxt.SetFontStyle(n"Medium");
        modeTxt.SetFontSize(14);
        modeTxt.SetSize(new Vector2(180.0, 20.0));
        modeTxt.SetLetterCase(textLetterCase.OriginalCase);
        modeTxt.SetTranslation(new Vector2(15.0, 8.0));
        modeTxt.SetVisible(true);
        modeTxt.SetOpacity(1.0);
        modeTxt.Reparent(canvas);
      }
      this.modeText = modeTxt;

      let gearTxt: ref<inkText> = canvas.GetWidget(n"ITC_HUD_Gear") as inkText;
      if !IsDefined(gearTxt) {
        LogChannel(n"DEBUG", "ITC HUD: Creating Gear text widget");
        gearTxt = new inkText();
        gearTxt.SetName(n"ITC_HUD_Gear");
        gearTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        gearTxt.SetFontStyle(n"Bold");
        gearTxt.SetFontSize(42);
        gearTxt.SetSize(new Vector2(180.0, 50.0));
        gearTxt.SetLetterCase(textLetterCase.OriginalCase);
        gearTxt.SetTranslation(new Vector2(15.0, 20.0));
        gearTxt.SetVisible(true);
        gearTxt.SetOpacity(1.0);
        gearTxt.Reparent(canvas);
      }
      this.gearText = gearTxt;

      let statusTxt: ref<inkText> = canvas.GetWidget(n"ITC_HUD_Status") as inkText;
      if !IsDefined(statusTxt) {
        LogChannel(n"DEBUG", "ITC HUD: Creating Status text widget");
        statusTxt = new inkText();
        statusTxt.SetName(n"ITC_HUD_Status");
        statusTxt.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        statusTxt.SetFontStyle(n"Regular");
        statusTxt.SetFontSize(13);
        statusTxt.SetSize(new Vector2(180.0, 20.0));
        statusTxt.SetLetterCase(textLetterCase.OriginalCase);
        statusTxt.SetTranslation(new Vector2(15.0, 70.0));
        statusTxt.SetVisible(true);
        statusTxt.SetOpacity(1.0);
        statusTxt.Reparent(canvas);
      }
      this.statusText = statusTxt;

      this.__built = true;
      LogChannel(n"DEBUG", s"ITC HUD: Built successfully. canvas=\(IsDefined(this.rootCanvas)), modeText=\(IsDefined(this.modeText)), gearText=\(IsDefined(this.gearText)), statusText=\(IsDefined(this.statusText))");
    }

    this.ArmNextTick();
  }

  public func ArmNextTick() -> Void {
    if this.__tickArmed { return; }
    if !IsDefined(this.tick) {
      this.tick = ITC_HUDTick.Create(this);
    }
    this.__tickArmed = true;
    GameInstance.GetDelaySystem(GetGameInstance()).DelayCallback(this.tick, this.tickPeriod, false);
  }

  public func Refresh() -> Void {
    this.Ensure();
    if !this.__built { return; }

    let qs = GameInstance.GetQuestsSystem(GetGameInstance());
    if !IsDefined(qs) { return; }

    let posX: Int32 = qs.GetFact(n"itc_hud_pos_x");
    let posY: Int32 = qs.GetFact(n"itc_hud_pos_y");
    let fracX: Float = Cast<Float>(posX) / 100.0;
    let fracY: Float = Cast<Float>(posY) / 100.0;

    let inkSys: ref<inkSystem> = GameInstance.GetInkSystem();
    if IsDefined(inkSys) {
      let layer = inkSys.GetLayer(n"inkHUDLayer");
      if IsDefined(layer) {
        let size = layer.GetVirtualWindow().GetSize();
        let screenWidth: Float = size.X;
        let screenHeight: Float = size.Y;
        if screenWidth <= 0.0 { screenWidth = 1920.0; }
        if screenHeight <= 0.0 { screenHeight = 1080.0; }
        this.rootCanvas.SetTranslation(new Vector2(screenWidth * fracX, screenHeight * fracY));
      }
    }

    let vis: Int32 = qs.GetFact(n"itc_hud_visible");
    let mode: Int32 = qs.GetFact(n"itc_hud_mode");
    let gear: Int32 = qs.GetFact(n"itc_hud_gear");
    let diff: Int32 = qs.GetFact(n"itc_hud_diff");
    let brake: Int32 = qs.GetFact(n"itc_hud_handbrake");
    let clutch: Int32 = qs.GetFact(n"itc_hud_clutch");
    let footBrake: Int32 = qs.GetFact(n"itc_hud_brake");

    if IsDefined(this.rootCanvas) && IsDefined(this.backgroundCard) {
      this.rootCanvas.ReorderChild(this.backgroundCard, 0);
    }

    if vis != 1 {
      if IsDefined(this.rootCanvas) {
        this.rootCanvas.SetVisible(false);
      }
      this.lastVisible = 0;
      return;
    }

    if IsDefined(this.rootCanvas) {
      this.rootCanvas.SetVisible(true);
    }

    if !this.__dirty && mode == this.lastMode && gear == this.lastGear && diff == this.lastDiff && brake == this.lastBrake && vis == this.lastVisible && clutch == this.lastClutch && footBrake == this.lastFootBrake {
      return;
    }
    this.__dirty = false;
    this.lastMode = mode;
    this.lastGear = gear;
    this.lastDiff = diff;
    this.lastBrake = brake;
    this.lastVisible = vis;
    this.lastClutch = clutch;
    this.lastFootBrake = footBrake;

    LogChannel(n"DEBUG", s"ITC HUD: Refresh applied. Vis=\(vis), Mode=\(mode), Gear=\(gear), PB=\(brake), Clutch=\(clutch), FootBrake=\(footBrake), PosX=\(posX), PosY=\(posY)");


    let modeTxtStr: String = "AUTOMATIC";
    let modeColor: HDRColor;
    if mode == 1 {
      modeTxtStr = "MANUAL";
      modeColor.Red = 1.0; modeColor.Green = 0.75; modeColor.Blue = 0.0; modeColor.Alpha = 1.0;
    } else {
      if mode == 2 {
        modeTxtStr = "AUTO OVERRIDE";
        modeColor.Red = 1.0; modeColor.Green = 0.5; modeColor.Blue = 0.0; modeColor.Alpha = 1.0;
      } else {
        modeColor.Red = 0.5; modeColor.Green = 0.6; modeColor.Blue = 0.7; modeColor.Alpha = 0.8;
      }
    }
    if IsDefined(this.modeText) {
      this.modeText.SetVisible(true);
      this.modeText.SetOpacity(1.0);
      this.modeText.SetText(modeTxtStr);
      this.modeText.SetTintColor(modeColor);
      LogChannel(n"DEBUG", s"ITC HUD: SetModeText to \(modeTxtStr) with color R=\(modeColor.Red), G=\(modeColor.Green), B=\(modeColor.Blue)");
    }

    let gearStr: String = "";
    let gearColor: HDRColor;
    gearColor.Red = 1.0; gearColor.Green = 0.75; gearColor.Blue = 0.0; gearColor.Alpha = 1.0;

    if gear == 0 {
      gearStr = "R";
      gearColor.Red = 1.0; gearColor.Green = 0.25; gearColor.Blue = 0.25; gearColor.Alpha = 1.0;
    } else {
      if gear == 1 {
        gearStr = "N";
        gearColor.Red = 0.6; gearColor.Green = 0.6; gearColor.Blue = 0.6; gearColor.Alpha = 1.0;
      } else {
        if gear >= 200 {
          gearStr = "M" + IntToString(gear - 200);
        } else {
          if gear >= 100 {
            gearStr = "D" + IntToString(gear - 100);
          } else {
            gearStr = IntToString(gear - 1);
          }
        }
      }
    }

    if IsDefined(this.gearText) {
      this.gearText.SetVisible(true);
      this.gearText.SetOpacity(1.0);
      this.gearText.SetText(gearStr);
      this.gearText.SetTintColor(gearColor);
      LogChannel(n"DEBUG", s"ITC HUD: SetGearText to \(gearStr) with color R=\(gearColor.Red), G=\(gearColor.Green), B=\(gearColor.Blue)");
    }

    let statusStr: String = "";
    if brake == 1 {
      statusStr = statusStr + "[P] ";
    } else {
      statusStr = statusStr + "[ ] ";
    }

    if footBrake == 1 {
      statusStr = statusStr + "[B] ";
    } else {
      statusStr = statusStr + "[ ] ";
    }

    if clutch == 1 {
      statusStr = statusStr + "[C] ";
    } else {
      statusStr = statusStr + "[ ] ";
    }

    if diff == 1 {
      statusStr = statusStr + "LOCK";
    } else {
      statusStr = statusStr + "OPEN";
    }

    if IsDefined(this.statusText) {
      let statusColor: HDRColor;
      statusColor.Red = 0.8; statusColor.Green = 0.8; statusColor.Blue = 0.8; statusColor.Alpha = 1.0;
      this.statusText.SetVisible(true);
      this.statusText.SetOpacity(1.0);
      this.statusText.SetText(statusStr);
      this.statusText.SetTintColor(statusColor);
      LogChannel(n"DEBUG", s"ITC HUD: SetStatusText to \(statusStr) with color R=\(statusColor.Red), G=\(statusColor.Green), B=\(statusColor.Blue)");
    }
  }
}

@addField(UISystem)
public let itcHUD: ref<ITC_HUD>;

@wrapMethod(UISystem)
public final func PushGameContext(context: UIGameContext) -> Void {
  wrappedMethod(context);
  if !IsDefined(this.itcHUD) { this.itcHUD = new ITC_HUD(); }
  this.itcHUD.Ensure();
}

@wrapMethod(UISystem)
public final func PopGameContext(context: UIGameContext, opt invalidate: Bool) -> Void {
  wrappedMethod(context, invalidate);
  if !IsDefined(this.itcHUD) { this.itcHUD = new ITC_HUD(); }
  this.itcHUD.Ensure();
}

@wrapMethod(PlayerPuppet)
protected cb func OnTakeControl(resolver: EntityResolveComponentsInterface) -> Bool {
  let r = wrappedMethod(resolver);
  let uiSys: ref<UISystem> = GameInstance.GetUISystem(GetGameInstance());
  if IsDefined(uiSys) {
    if !IsDefined(uiSys.itcHUD) { uiSys.itcHUD = new ITC_HUD(); }
    uiSys.itcHUD.Ensure();
  }
  return r;
}
