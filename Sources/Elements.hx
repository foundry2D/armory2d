package ;

import zui.*;
import zui.Zui;
import zui.Canvas;

@:access(zui.Zui)
class Elements {
	var ui:Zui;
	var cui:Zui;
	var canvas:TCanvas;

	static var defaultWindowW = 240;
	static var windowW = defaultWindowW;
	static var uiw(get, null):Int;
	static function get_uiw():Int {
		return Std.int(windowW * Main.prefs.scaleFactor);
	}
	static var coffX = 40.0;
	static var coffY = 40.0;

	var dropPath = "";
	var drag = false;
	var dragLeft = false;
	var dragTop = false;
	var dragRight = false;
	var dragBottom = false;
	var assetNames:Array<String> = [];
	var dragAsset:TAsset = null;
	var resizeCanvas = false;
	var zoom = 1.0;

	var showFiles = false;
	var foldersOnly = false;
	var filesDone:String->Void = null;
	var uimodal:Zui;

	static var grid:kha.Image = null;
	static var timeline:kha.Image = null;

	var selectedFrame = 0;

	var selectedElem:TElement = null;
	var hwin = Id.handle();
	var lastW = 0;
	var lastH = 0;
	var lastCanvasW = 0;
	var lastCanvasH = 0;

	public function new(canvas:TCanvas) {
		this.canvas = canvas;

		// Reimport assets
		if (canvas.assets.length > 0) {
			var assets = canvas.assets;
			canvas.assets = [];
			for (a in assets) importAsset(a.file);
		}

		kha.Assets.loadEverything(loaded);
	}

	static function toRelative(path:String, cwd:String):String {
		path = haxe.io.Path.normalize(path);
		cwd = haxe.io.Path.normalize(cwd);
		
		var ar:Array<String> = [];
		var ar1 = path.split("/");
		var ar2 = cwd.split("/");
		
		var index = 0;
		while (ar1[index] == ar2[index]) index++;
		
		for (i in 0...ar2.length - index) ar.push("..");
		
		for (i in index...ar1.length) ar.push(ar1[i]);
		
		return ar.join("/");
	}

	static function toAbsolute(path:String, cwd:String):String {
		return haxe.io.Path.normalize(cwd + "/" + path);
	}

	static inline function toDegrees(radians:Float):Float { return radians * 57.29578; }
	static inline function toRadians(degrees:Float):Float { return degrees * 0.0174532924; }

	function loaded() {
		var t = Reflect.copy(Themes.dark);
		t.FILL_WINDOW_BG = true;
		ui = new Zui({scaleFactor: Main.prefs.scaleFactor, font: kha.Assets.fonts.DroidSans, theme: t, color_wheel: kha.Assets.images.color_wheel});
		cui = new Zui({scaleFactor: 1.0, font: kha.Assets.fonts.DroidSans, autoNotifyInput: false});
		uimodal = new Zui( { font: kha.Assets.fonts.DroidSans, scaleFactor: Main.prefs.scaleFactor } );

		kha.System.notifyOnDropFiles(function(path:String) {
			dropPath = StringTools.rtrim(path);
			dropPath = toRelative(dropPath, Main.cwd);
		});

		kha.System.notifyOnRender(render);
		kha.Scheduler.addTimeTask(update, 0, 1 / 60);
	}

	function importAsset(path:String) {
		if (!StringTools.endsWith(path, ".jpg") &&
			!StringTools.endsWith(path, ".png") &&
			!StringTools.endsWith(path, ".k") &&
			!StringTools.endsWith(path, ".hdr")) return;
		
		var abspath = toAbsolute(path, Main.cwd);
		abspath = kha.System.systemId == "Windows" ? StringTools.replace(abspath, "/", "\\") : abspath;

		kha.Assets.loadImageFromPath(abspath, false, function(image:kha.Image) {
			var ar = path.split("/");
			var name = ar[ar.length - 1];
			var asset:TAsset = { name: name, file: path, id: Canvas.getAssetId(canvas) };
			canvas.assets.push(asset);
			Canvas.assetMap.set(asset.id, image);

			assetNames.push(name);
			hwin.redraws = 2;
		});
	}

	function unique(s:String):String {
		// for (e in canvas.elements) {
			// if (s == e.name) {
				// return unique(s + '.001')
			// }
		// }
		return s;
	}

	function makeElem(type:ElementType) {
		var name = "";
		var height = 100;
		if (type == ElementType.Text) {
			name = unique("Text");
			height = 40;
		}
		else if (type == ElementType.Button) {
			name = unique("Button");
			height = 20;
		}
		else if (type == ElementType.Image) {
			name = unique("Image");
		}
		var elem:TElement = {
			id: Canvas.getElementId(canvas),
			type: type,
			name: name,
			event: "",
			x: 0,
			y: 0,
			width: 150,
			height: height,
			rotation: 0,
			text: "My " + name,
			asset: "",
			color: 0xffffffff,
			anchor: 0,
			children: [],
			visible: true
		};
		return elem;
	}

	function getEnumTexts():Array<String> {
		return assetNames.length > 0 ? assetNames : [""];
	}

	function getAssetIndex(asset:String):Int {
		for (i in 0...canvas.assets.length) if (asset == canvas.assets[i].name) return i;
		return 0;
	}

	function resize() {
		if (grid != null) {
			grid.unload();
			grid = null;
		}
	}

	function drawGrid() {
		var ww = kha.System.windowWidth();
		var wh = kha.System.windowHeight();
		var w = ww + 40 * 2;
		var h = wh + 40 * 2;
		grid = kha.Image.createRenderTarget(w, h);
		grid.g2.begin(true, 0xff242424);
		for (i in 0...Std.int(h / 40) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(0, i * 40, w, i * 40);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(0, i * 40 + 20, w, i * 40 + 20);
		}
		for (i in 0...Std.int(w / 40) + 1) {
			grid.g2.color = 0xff282828;
			grid.g2.drawLine(i * 40, 0, i * 40, h);
			grid.g2.color = 0xff323232;
			grid.g2.drawLine(i * 40 + 20, 0, i * 40 + 20, h);
		}

		grid.g2.end();
	}

	function drawTimeline() {
		timeline = kha.Image.createRenderTarget(kha.System.windowWidth() - uiw, 60);
		var g = timeline.g2;
		g.begin(true, 0xff222222);
		g.font = kha.Assets.fonts.DroidSans;
		g.fontSize = 16;

		// Labels
		for (i in 0...Std.int(125 / 5) + 1) {
			g.drawString(i * 5 + "", i * 55, 0);
		}

		// Frames
		for (i in 0...125) {
			g.color = i % 5 == 0 ? 0xff444444 : 0xff333333;
			g.fillRect(i * 11, 30, 10, 30);
		}

		g.end();
	}

	public function render(framebuffer: kha.Framebuffer): Void {

		if (dropPath != "") {
			importAsset(dropPath);
			dropPath = "";
		}

		// Bake
		if (grid == null) drawGrid();
		if (timeline == null) drawTimeline();

		var g = framebuffer.g2;
		g.begin();

		g.color = 0xffffffff;
		g.drawImage(grid, coffX % 40 - 40, coffY % 40 - 40);

		// Canvas outline
		canvas.x = coffX;
		canvas.y = coffY;
		g.drawRect(canvas.x, canvas.y, scaled(canvas.width), scaled(canvas.height), 1.0);
		// Canvas resize
		g.drawRect(canvas.x + scaled(canvas.width) - 3, canvas.y + scaled(canvas.height) - 3, 6, 6, 1);

		Canvas.screenW = canvas.width;
		Canvas.screenH = canvas.height;
		Canvas.draw(cui, canvas, g);

		// Outline selected elem
		if (selectedElem != null) {
			g.color = 0xffffffff;
			// Resize rects
			var ex = scaled(selectedElem.x);
			var ey = scaled(selectedElem.y);
			var ew = scaled(selectedElem.width);
			var eh = scaled(selectedElem.height);
			g.drawRect(canvas.x + ex, canvas.y + ey, ew, eh);
			g.drawRect(canvas.x + ex - 3, canvas.y + ey - 3, 6, 6);
			g.drawRect(canvas.x + ex - 3 + ew / 2, canvas.y + ey - 3, 6, 6);
			g.drawRect(canvas.x + ex - 3 + ew, canvas.y + ey - 3, 6, 6);
			g.drawRect(canvas.x + ex - 3, canvas.y + ey - 3 + eh / 2, 6, 6);
			g.drawRect(canvas.x + ex - 3 + ew, canvas.y + ey - 3 + eh / 2, 6, 6);
			g.drawRect(canvas.x + ex - 3, canvas.y + ey - 3 + eh, 6, 6);
			g.drawRect(canvas.x + ex - 3 + ew / 2, canvas.y + ey - 3 + eh, 6, 6);
			g.drawRect(canvas.x + ex - 3 + ew, canvas.y + ey - 3 + eh, 6, 6);
		}

		// Timeline
		var showTimeline = true;
		if (showTimeline) {
			g.color = 0xffffffff;
			var ty = kha.System.windowHeight() - timeline.height;
			g.drawImage(timeline, 0, ty);

			g.color = 0xff205d9c;
			g.fillRect(selectedFrame * 11, ty + 30, 10, 30);
		}

		g.end();

		ui.begin(g);

		if (ui.window(hwin, kha.System.windowWidth() - uiw, 0, uiw, kha.System.windowHeight(), false)) {

			var htab = Id.handle();
			if (ui.tab(htab, "Project")) {

				if (ui.button("Save")) {

					// Unpan
					canvas.x = 0;
					canvas.y = 0;
					#if kha_krom
					Krom.fileSaveBytes(Main.prefs.path, haxe.io.Bytes.ofString(haxe.Json.stringify(canvas)).getData());
					#end

					var filesPath = Main.prefs.path.substr(0, Main.prefs.path.length - 5); // .json
					filesPath += '.files';
					var filesList = '';
					for (a in canvas.assets) filesList += a.file + '\n';
					#if kha_krom
					Krom.fileSaveBytes(filesPath, haxe.io.Bytes.ofString(filesList).getData());
					#end

					canvas.x = coffX;
					canvas.y = coffY;
				}

				ui.row([1/3, 1/3, 1/3]);
				if (ui.button("Text")) {
					selectedElem = makeElem(ElementType.Text);
					canvas.elements.push(selectedElem);
				}
				if (ui.button("Image")) {
					selectedElem = makeElem(ElementType.Image);
					canvas.elements.push(selectedElem);
				}
				if (ui.button("Button")) {
					selectedElem = makeElem(ElementType.Button);
					canvas.elements.push(selectedElem);
				}

				if (ui.panel(Id.handle({selected: false}), "Canvas")) {
					// ui.row([1/3, 1/3, 1/3]);
					// if (ui.button("New")) {
					// 	untyped __js__("const {dialog} = require('electron').remote");
					// 	untyped __js__("dialog.showMessageBox({type: 'question', buttons: ['Yes', 'No'], title: 'Confirm', message: 'Create new canvas?'})");
					// }

					// if (ui.button("Open")) {
					// 	untyped __js__("const {dialog} = require('electron').remote");
					// 	untyped __js__("console.log(dialog.showOpenDialog({properties: ['openFile', 'openDirectory', 'multiSelections']}))");
					// }

					if (ui.button("New")) {
						canvas.elements = [];
						selectedElem = null;
					}

					canvas.name = ui.textInput(Id.handle({text: canvas.name}), "Name", Right);
					ui.row([1/2, 1/2]);
					var strw = ui.textInput(Id.handle({text: canvas.width + ""}), "Width", Right);
					var strh = ui.textInput(Id.handle({text: canvas.height + ""}), "Height", Right);
					canvas.width = Std.parseInt(strw);
					canvas.height = Std.parseInt(strh);
				}

				if (ui.panel(Id.handle({selected: true}), "Outliner")) {

					var i = 0;
					function drawList(h:zui.Zui.Handle, elem:TElement) {
						var b = false;
						// Highlight
						if (selectedElem == elem) {
							ui.g.color = 0xff205d9c;
							ui.g.fillRect(0, ui._y, ui._windowW, ui.t.ELEMENT_H);
							ui.g.color = 0xffffffff;
						}
						var started = ui.getStarted();
						// Select
						if (started && !ui.inputDownR) {
							selectedElem = elem;
						}
						// Parenting
						if (started && ui.inputDownR) {
							getSelectedArray(canvas.elements).remove(selectedElem);
							if (elem == selectedElem) {
								// Unparent
								canvas.elements.push(selectedElem);
							}
							else {
								if (elem.children == null) elem.children = [];
								elem.children.push(selectedElem);
							}
						}
						// Draw
						if (elem.children != null && elem.children.length > 0) {
							ui.row([1/13, 12/13]);
							b = ui.panel(h.nest(i, {selected: true}), "", 0, true);
							ui.text(elem.name);
						}
						else {
							ui._x += 18; // Sign offset
							ui.text(elem.name);
							ui._x -= 18;
						}
						// Draw children
						i++;
						if (b) {
							for (c in elem.children) {
								ui.indent();
								drawList(h, c);
								ui.unindent();
							}
						}
					}
					for (elem in canvas.elements) {
						drawList(Id.handle(), elem);
					}

					ui.row([1/3, 1/3, 1/3]);
					var elems = canvas.elements;
					if (ui.button("Up") && selectedElem != null) {
						moveElem(1);
					}
					if (ui.button("Down") && selectedElem != null) {
						moveElem(-1);
					}
					if (ui.button("Remove") && selectedElem != null) {
						removeSelectedElem();
					}
				}

				if (selectedElem != null) {
					var elem = selectedElem;
					var id = elem.id;

					if (ui.panel(Id.handle({selected: true}), "Properties")) {
						elem.visible = ui.check(Id.handle().nest(id, {selected: elem.visible}), "Visible");
						elem.name = ui.textInput(Id.handle().nest(id, {text: elem.name}), "Name", Right);
						elem.text = ui.textInput(Id.handle().nest(id, {text: elem.text}), "Text", Right);
						ui.row([1/4, 1/4, 1/4, 1/4]);
						var handlex = Id.handle().nest(id, {text: elem.x + ""});
						var handley = Id.handle().nest(id, {text: elem.y + ""});
						// if (drag) {
							handlex.text = elem.x + "";
							handley.text = elem.y + "";
						// }
						var strx = ui.textInput(handlex, "X", Right);
						var stry = ui.textInput(handley, "Y", Right);
						elem.x = Std.parseFloat(strx);
						elem.y = Std.parseFloat(stry);
						// ui.row([1/2, 1/2]);
						var handlew = Id.handle().nest(id, {text: elem.width + ""});
						var handleh = Id.handle().nest(id, {text: elem.height + ""});
						// if (drag) {
							handlew.text = elem.width + "";
							handleh.text = elem.height + "";
						// }
						var strw = ui.textInput(handlew, "W", Right);
						var strh = ui.textInput(handleh, "H", Right);
						elem.width = Std.int(Std.parseFloat(strw));
						elem.height = Std.int(Std.parseFloat(strh));
						var handlerot = Id.handle().nest(id, {value: toDegrees(elem.rotation)});
						elem.rotation = toRadians(ui.slider(handlerot, "Rotation", 0.0, 360.0, true));
						var assetPos = ui.combo(Id.handle().nest(id, {position: getAssetIndex(elem.asset)}), getEnumTexts(), "Asset", true, Right);
						elem.asset = getEnumTexts()[assetPos];
						elem.color = Ext.colorWheel(ui, Id.handle().nest(id, {color: 0xffffff}), true, null, true);
					}

					if (ui.panel(Id.handle({selected: false}), "Anchor")) {
						var hanch = Id.handle().nest(id, {position: elem.anchor});
						ui.row([4/11,3/11,4/11]);
						ui.radio(hanch, 0, "Top-Left");
						ui.radio(hanch, 1, "Top");
						ui.radio(hanch, 2, "Top-Right");
						ui.row([4/11,3/11,4/11]);
						ui.radio(hanch, 3, "Left");
						ui.radio(hanch, 4, "Center");
						ui.radio(hanch, 5, "Right");
						ui.row([4/11,3/11,4/11]);
						ui.radio(hanch, 6, "Bot-Left");
						ui.radio(hanch, 7, "Bottom");
						ui.radio(hanch, 8, "Bot-Right");
						elem.anchor = hanch.position;
					}

					if (ui.panel(Id.handle({selected: false}), "Script")) {
						elem.event = ui.textInput(Id.handle().nest(id, {text: elem.event}), "Event", Right);
					}

					if (ui.panel(Id.handle({selected: false}), "Timeline")) {
						// ui.row([1/2,1/2]);
						// ui.button("Insert");
						// ui.button("Remove");
					}
				}
			}

			if (ui.tab(htab, "Import")) {
				if (ui.button("Import image")) {
					showFiles = true;
					foldersOnly = false;
					filesDone = function(path:String) {
						path = StringTools.rtrim(path);
						path = toRelative(path, Main.cwd);
						importAsset(path);
					}
				}
				
				if (canvas.assets.length > 0) {
					ui.text("(Drag adnd drop images to canvas)", zui.Zui.Align.Center);

					var i = canvas.assets.length - 1;
					while (i >= 0) {
						var asset = canvas.assets[i];
						if (ui.image(getImage(asset)) == State.Started) {
							dragAsset = asset;
						}
						ui.row([7/8, 1/8]);
						asset.name = ui.textInput(Id.handle().nest(asset.id, {text: asset.name}), "", Right);
						assetNames[i] = asset.name;
						if (ui.button("X")) {
							getImage(asset).unload();
							canvas.assets.splice(i, 1);
							assetNames.splice(i, 1);
						}
						i--;
					}
				}
				else {
					ui.text("(Drag and drop images here)", zui.Zui.Align.Center);
				}
			}

			if (ui.tab(htab, "Preferences")) {
				var hscale = Id.handle({value: 1.0});
				ui.slider(hscale, "UI Scale", 0.5, 4.0, true);
				if (ui.changed && !ui.inputDown) {
					ui.setScale(hscale.value);
					windowW = Std.int(defaultWindowW * hscale.value);
				}
				Main.prefs.window_vsync = ui.check(Id.handle({selected: true}), "VSync");
				// if (ui.button("Save")) {
				// 	#if kha_krom
				// 	Krom.fileSaveBytes("config.arm", haxe.io.Bytes.ofString(haxe.Json.stringify(armory.data.Config.raw)).getData());
				// 	#end
				// }
				// ui.text("armory2d");

				if (ui.panel(Id.handle({selected: true}), "Console")) {
					// ui.text(lastTrace);
				}
			}
		}
		ui.end();

		g.begin(false);

		if (dragAsset != null) {
			var w = Math.min(128, getImage(dragAsset).width);
			var ratio = w / getImage(dragAsset).width;
			var h = getImage(dragAsset).height * ratio;
			g.drawScaledImage(getImage(dragAsset), ui.inputX, ui.inputY, w, h);
		}

		g.end();

		if (lastW > 0 && (lastW != kha.System.windowWidth() || lastH != kha.System.windowHeight())) {
			resize();
		}
		else if (lastCanvasW > 0 && (lastCanvasW != canvas.width || lastCanvasH != canvas.height)) {
			resize();
		}
		lastW = kha.System.windowWidth();
		lastH = kha.System.windowHeight();
		lastCanvasW = canvas.width;
		lastCanvasH = canvas.height;

		if (showFiles) renderFiles(g);
	}

	function getSelectedArray(ar:Array<TElement>):Array<TElement> {
		if (ar == null) return null;
		for (e in ar) {
			if (e == selectedElem) return ar;
			var res = getSelectedArray(e.children);
			if (res != null) return res;
		}
		return null;
	}

	function moveElem(d:Int) {
		var ar = getSelectedArray(canvas.elements);
		if (ar.length <= 1) return;

		var i = ar.indexOf(selectedElem) + d;
		if (i < 0 || i >= ar.length) return;

		ar.remove(selectedElem);
		ar.insert(i, selectedElem);
	}

	function getImage(asset:TAsset):kha.Image {
		return Canvas.assetMap.get(asset.id);
	}

	function removeSelectedElem() {
		canvas.elements.remove(selectedElem);
		selectedElem = null;
	}

	function acceptDrag(index:Int) {
		var elem = makeElem(ElementType.Image);
		elem.asset = assetNames[index];
		elem.x = ui.inputX - canvas.x;
		elem.y = ui.inputY - canvas.y;
		elem.width = getImage(canvas.assets[index]).width;
		elem.height = getImage(canvas.assets[index]).height;
		canvas.elements.push(elem);
		selectedElem = elem;
	}

	function hitbox(x:Float, y:Float, w:Float, h:Float):Bool {
		return ui.inputX > x && ui.inputX < x + w && ui.inputY > y && ui.inputY < y + h;
	}

	public function update() {

		// Drag from assets panel
		if (ui.inputReleased && dragAsset != null) {
			if (ui.inputX < kha.System.windowWidth() - uiw) {
				var index = 0;
				for (i in 0...canvas.assets.length) if (canvas.assets[i] == dragAsset) { index = i; break; }
				acceptDrag(index);
			}
			dragAsset = null;
		}
		if (dragAsset != null) return;

		// Select elem
		if (ui.inputStarted && ui.inputDownR) {
			var i = canvas.elements.length;
			for (elem in canvas.elements) {
				var ex = scaled(elem.x);
				var ey = scaled(elem.y);
				var ew = scaled(elem.width);
				var eh = scaled(elem.height);
				if (hitbox(canvas.x + ex, canvas.y + ey, ew, eh) &&
					selectedElem != elem) {
					selectedElem = elem;
					break;
				}
			}
		}

		// Pan canvas
		if (ui.inputDownR) {
			coffX += Std.int(ui.inputDX);
			coffY += Std.int(ui.inputDY);
		}

		// Zoom canvas
		if (ui.inputWheelDelta != 0) {
			zoom += -ui.inputWheelDelta / 10;
			if (zoom < 0.4) zoom = 0.4;
			else if (zoom > 1.0) zoom = 1.0;
			zoom = Math.round(zoom * 10) / 10;
			cui.SCALE = cui.ops.scaleFactor * zoom;
		}

		// Select frame
		if (timeline != null) {
			var ty = kha.System.windowHeight() - timeline.height;
			if (ui.inputDown && ui.inputY > ty && ui.inputX < kha.System.windowWidth() - uiw) {
				selectedFrame = Std.int(ui.inputX / 11);
			}
		}

		if (selectedElem != null) {
			var elem = selectedElem;
			var ex = scaled(elem.x);
			var ey = scaled(elem.y);
			var ew = scaled(elem.width);
			var eh = scaled(elem.height);

			// Drag selected elem
			if (ui.inputStarted && ui.inputDown &&
				hitbox(canvas.x + ex - 3, canvas.y + ey - 3, ew + 3, eh + 3)) {
				drag = true;
				// Resize
				dragLeft = dragRight = dragTop = dragBottom = false;
				if (ui.inputX > canvas.x + ex + ew - 3) dragRight = true;
				else if (ui.inputX < canvas.x + ex + 3) dragLeft = true;
				if (ui.inputY > canvas.y + ey + eh - 3) dragBottom = true;
				else if (ui.inputY < canvas.y + ey + 3) dragTop = true;

			}
			if (ui.inputReleased && drag) {
				drag = false;
			}

			if (drag) {
				hwin.redraws = 2;

				if (dragRight) elem.width += Std.int(ui.inputDX);
				else if (dragLeft) { elem.x += Std.int(ui.inputDX); elem.width -= Std.int(ui.inputDX); }
				if (dragBottom) elem.height += Std.int(ui.inputDY);
				else if (dragTop) { elem.y += Std.int(ui.inputDY); elem.height -= Std.int(ui.inputDY); }
			
				if (!dragLeft && !dragRight && !dragBottom && !dragTop) {
					elem.x += ui.inputDX;
					elem.y += ui.inputDY;
				}
			}

			// Move with arrows
			if (ui.isKeyDown && !ui.isTyping) {
				if (ui.key == kha.input.KeyCode.Left) elem.x--;
				if (ui.key == kha.input.KeyCode.Right) elem.x++;
				if (ui.key == kha.input.KeyCode.Up) elem.y--;
				if (ui.key == kha.input.KeyCode.Down) elem.y++;

				if (ui.key == kha.input.KeyCode.Backspace || ui.char == "x") removeSelectedElem();

				hwin.redraws = 2;
			}
		}

		// Canvas resize
		if (ui.inputStarted && hitbox(canvas.x + scaled(canvas.width) - 3, canvas.y + scaled(canvas.height) - 3, 6, 6)) {
			resizeCanvas = true;
		}
		if (ui.inputReleased && resizeCanvas) {
			resizeCanvas = false;
		}
		if (resizeCanvas) {
			canvas.width += Std.int(ui.inputDX);
			canvas.height += Std.int(ui.inputDY);
			if (canvas.width < 1) canvas.width = 1;
			if (canvas.height < 1) canvas.height = 1;
		}

		updateFiles();
	}

	function updateFiles() {
		if (!showFiles) return;

		if (ui.inputReleased) {
			var appw = kha.System.windowWidth();
			var apph = kha.System.windowHeight();
			var left = appw / 2 - modalRectW / 2;
			var right = appw / 2 + modalRectW / 2;
			var top = apph / 2 - modalRectH / 2;
			var bottom = apph / 2 + modalRectH / 2;
			if (ui.inputX < left || ui.inputX > right || ui.inputY < top + modalHeaderH || ui.inputY > bottom) {
				showFiles = false;
			}
		}
	}

	static var modalW = 625;
	static var modalH = 545;
	static var modalHeaderH = 66;
	static var modalRectW = 625; // No shadow
	static var modalRectH = 545;

	static var path = '/';
	function renderFiles(g:kha.graphics2.Graphics) {
		var appw = kha.System.windowWidth();
		var apph = kha.System.windowHeight();
		var left = appw / 2 - modalW / 2;
		var top = apph / 2 - modalH / 2;
		g.color = 0xff202020;
		g.fillRect(left, top, modalW, modalH);

		var leftRect = Std.int(appw / 2 - modalRectW / 2);
		var rightRect = Std.int(appw / 2 + modalRectW / 2);
		var topRect = Std.int(apph / 2 - modalRectH / 2);
		var bottomRect = Std.int(apph / 2 + modalRectH / 2);
		topRect += modalHeaderH;
		
		g.end();
		uimodal.begin(g);
		if (uimodal.window(Id.handle(), leftRect, topRect, modalRectW, modalRectH - 100)) {
			var pathHandle = Id.handle();
			pathHandle.text = uimodal.textInput(pathHandle);
			path = zui.Ext.fileBrowser(uimodal, pathHandle, foldersOnly);
		}
		uimodal.end(false);
		g.begin(false);

		uimodal.beginLayout(g, rightRect - 100, bottomRect - 30, 100);
		if (uimodal.button("OK")) {
			showFiles = false;
			filesDone(path);
		}
		uimodal.endLayout(false);

		uimodal.beginLayout(g, rightRect - 200, bottomRect - 30, 100);
		if (uimodal.button("Cancel")) {
			showFiles = false;
		}
		uimodal.endLayout();

		g.begin(false);
	}

	inline function scaled(f: Float): Int { return Std.int(f * cui.SCALE); }
}
