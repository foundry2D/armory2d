package ;

import zui.*;
import zui.Zui;
import zui.Canvas;

@:access(zui.Zui)
class Elements {
	var ui: Zui;
	var cui: Zui;
	var bg:kha.Image = null;
	var canvas:TCanvas;

	static inline var uiw = 240;
	static inline var coff = 40;

	var dropPath = "";
	var drag = false;
	var dragLeft = false;
	var dragTop = false;
	var dragRight = false;
	var dragBottom = false;
	var assetNames:Array<String> = [];
	var dragAsset:TAsset = null;

	public function new(canvas:TCanvas) {
		this.canvas = canvas;

		// Reimport assets
		if (canvas.assets.length > 0) {
			var assets = canvas.assets;
			canvas.assets = [];
			for (a in assets) importAsset(a.file);
		}

		// var _onDrop = onDrop;
		// untyped __js__("
		// document.ondragover = document.ondrop = (ev) => {
		// 	ev.preventDefault()
		// }
		// document.body.ondrop = (ev) => {
		// 	_onDrop(ev.dataTransfer.files[0].path);
		// 	ev.preventDefault()
		// }
		// ");

		kha.Assets.loadEverything(loaded);
	}

	function loaded() {
		var t = Reflect.copy(Themes.dark);
		t.FILL_WINDOW_BG = true;
		ui = new Zui({font: kha.Assets.fonts.DroidSans, theme: t, color_wheel: kha.Assets.images.color_wheel});
		cui = new Zui({font: kha.Assets.fonts.DroidSans, autoNotifyInput: false});

		kha.System.notifyOnDropFiles(function(path:String) {
			dropPath = StringTools.rtrim(path);			
		});

		kha.System.notifyOnRender(render);
		kha.Scheduler.addTimeTask(update, 0, 1 / 60);
	}

	function importAsset(path:String) {
		if (!StringTools.endsWith(path, ".jpg") &&
			!StringTools.endsWith(path, ".png") &&
			!StringTools.endsWith(path, ".k") &&
			!StringTools.endsWith(path, ".hdr")) return;
		
		kha.LoaderImpl.loadImageFromDescription({ files: [path] }, function(image:kha.Image) {
			var ar = kha.System.systemId == "Windows" ? path.split("\\") : path.split("/");
			var name = ar[ar.length - 1];
			var asset:TAsset = { name: name, file: path, id: Canvas.getAssetId(canvas) };
			canvas.assets.push(asset);
			Canvas.assetMap.set(asset.id, image);

			assetNames.push(name);
			hwin.redraws = 2;
		});
	}

	function makeElem(type:ElementType) {
		var name = "";
		var height = 100;
		if (type == ElementType.Text) {
			name = "Text";
			height = 48;
		}
		else if (type == ElementType.Button) {
			name = "Button";
		}
		else if (type == ElementType.Image) {
			name = "Image";
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
			text: name,
			asset: "",
			color: 0xffffff,
			anchor: 0,
			children: []
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

	var selectedElem = -1;
	var hwin = Id.handle();
	var hradio = Id.handle();
	public function render(framebuffer: kha.Framebuffer): Void {

		if (dropPath != "") {
			importAsset(dropPath);
			dropPath = "";
		}

		if (bg == null) {
			var w = kha.System.windowWidth();
			var h = kha.System.windowHeight();
			bg = kha.Image.createRenderTarget(w, h);
			bg.g2.begin(true, 0xff141414);
			for (i in 0...Std.int(h / 40) + 1) {
				bg.g2.color = 0xff303030;
				bg.g2.drawLine(0, i * 40, w, i * 40);
				bg.g2.color = 0xff202020;
				bg.g2.drawLine(0, i * 40 + 20, w, i * 40 + 20);
			}
			for (i in 0...Std.int(w / 40) + 1) {
				bg.g2.color = 0xff303030;
				bg.g2.drawLine(i * 40, 0, i * 40, h);
				bg.g2.color = 0xff202020;
				bg.g2.drawLine(i * 40 + 20, 0, i * 40 + 20, h);
			}

			bg.g2.color = 0xffffffff;
			canvas.x = coff;
			canvas.y = coff;
			bg.g2.drawRect(canvas.x, canvas.y, canvas.width, canvas.height, 1.0);

			bg.g2.end();
		}

		var g = framebuffer.g2;

		g.begin();

		g.color = 0xffffffff;
		g.drawImage(bg, 0, 0);

		g.font = kha.Assets.fonts.DroidSans;
		g.fontSize = 40;
		var title = canvas.name + ", " + canvas.width + "x" + canvas.height;
		var titlew = g.font.width(40, title);
		var titleh = g.font.height(40);
		g.color = 0xffffffff;
		g.drawString(title, kha.System.windowWidth() - titlew - 30 - uiw, kha.System.windowHeight() - titleh - 10);
		
		Canvas.draw(cui, canvas, g);

		// Outline selected elem
		if (selectedElem >= 0 && selectedElem < canvas.elements.length) {
			var elem = canvas.elements[selectedElem];
			g.color = 0xffffffff;
			g.drawRect(canvas.x + elem.x, canvas.y + elem.y, elem.width, elem.height, 1);
			g.drawRect(canvas.x + elem.x - 3, canvas.y + elem.y - 3, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width / 2, canvas.y + elem.y - 3, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width, canvas.y + elem.y - 3, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3, canvas.y + elem.y - 3 + elem.height / 2, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width, canvas.y + elem.y - 3 + elem.height / 2, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3, canvas.y + elem.y - 3 + elem.height, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width / 2, canvas.y + elem.y - 3 + elem.height, 6, 6, 1);
			g.drawRect(canvas.x + elem.x - 3 + elem.width, canvas.y + elem.y - 3 + elem.height, 6, 6, 1);
		}

		g.end();

		ui.begin(g);
		if (ui.window(hwin, kha.System.windowWidth() - uiw, 0, uiw, kha.System.windowHeight(), false)) {

			if (ui.button("Save")) {
				// untyped __js__("const {dialog} = require('electron').remote");
				// untyped __js__("console.log(dialog.showSaveDialog({properties: ['saveFile', 'saveDirectory']}))");
				// untyped __js__("var fs = require('fs')");
				// untyped __js__("fs.writeFileSync({0}, {1})", Main.prefs.path, haxe.Json.stringify(canvas));
				
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

				canvas.x = coff;
				canvas.y = coff;
			}

			if (ui.panel(Id.handle({selected: false}), "CANVAS")) {
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
					selectedElem = -1;
				}

				canvas.name = ui.textInput(Id.handle({text: canvas.name}), "Name", Right);
				ui.row([1/2, 1/2]);
				var strw = ui.textInput(Id.handle({text: canvas.width + ""}), "Width", Right);
				var strh = ui.textInput(Id.handle({text: canvas.height + ""}), "Height", Right);
				canvas.width = Std.parseInt(strw);
				canvas.height = Std.parseInt(strh);
			}

			ui.separator();

			if (ui.panel(Id.handle({selected: true}), "TREE")) {
				ui.row([1/3, 1/3, 1/3]);
				if (ui.button("Text")) {
					var elem = makeElem(ElementType.Text);
					canvas.elements.push(elem);
					hradio.position = canvas.elements.length - 1;
				}
				if (ui.button("Image")) {
					var elem = makeElem(ElementType.Image);
					canvas.elements.push(elem);
					hradio.position = canvas.elements.length - 1;
				}
				if (ui.button("Button")) {
					var elem = makeElem(ElementType.Button);
					canvas.elements.push(elem);
					hradio.position = canvas.elements.length - 1;
				}

				var i = canvas.elements.length - 1;
				while (i >= 0) {
					var elem = canvas.elements[i];
					if (ui.radio(hradio, i, elem.name)) selectedElem = i;
					i--;
				}
				ui.row([1/3, 1/3, 1/3]);
				var temp1 = ui.t.BUTTON_BG_COL;
				var temp2 = ui.t.BUTTON_BG_COL_HOVER;
				var temp3 = ui.t.BUTTON_BG_COL_PRESSED;
				ui.t.BUTTON_BG_COL = 0xff343436;
				ui.t.BUTTON_BG_COL_HOVER = 0xff444446;
				ui.t.BUTTON_BG_COL_PRESSED = 0xff303030;
				var elems = canvas.elements;
				if (ui.button("Up") && selectedElem < elems.length - 1) {
					var t = canvas.elements[selectedElem];
					canvas.elements[selectedElem] = canvas.elements[selectedElem + 1];
					canvas.elements[selectedElem + 1] = t;
					selectedElem++;
					hradio.position = selectedElem;
				}
				if (ui.button("Down") && selectedElem > 0) {
					var t = canvas.elements[selectedElem];
					canvas.elements[selectedElem] = canvas.elements[selectedElem - 1];
					canvas.elements[selectedElem - 1] = t;
					selectedElem--;
					hradio.position = selectedElem;
				}
				if (ui.button("Remove")) {
					removeSelectedElem();
				}
				ui.t.BUTTON_BG_COL = temp1;
				ui.t.BUTTON_BG_COL_HOVER = temp2;
				ui.t.BUTTON_BG_COL_PRESSED = temp3;
			}

			ui.separator();

			if (ui.panel(Id.handle({selected: true}), "PROPERTIES")) {
				if (selectedElem >= 0) {
					var elem = canvas.elements[selectedElem];
					var id = elem.id;
					ui.row([1/2, 1/2]);
					elem.name = ui.textInput(Id.handle().nest(id, {text: elem.name}), "Name", Right);
					elem.event = ui.textInput(Id.handle().nest(id, {text: elem.event}), "Event", Right);
					ui.row([1/2, 1/2]);
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
					ui.row([1/2, 1/2]);
					var handlew = Id.handle().nest(id, {text: elem.width + ""});
					var handleh = Id.handle().nest(id, {text: elem.height + ""});
					// if (drag) {
						handlew.text = elem.width + "";
						handleh.text = elem.height + "";
					// }
					var strw = ui.textInput(handlew, "Width", Right);
					var strh = ui.textInput(handleh, "Height", Right);
					elem.width = Std.int(Std.parseFloat(strw));
					elem.height = Std.int(Std.parseFloat(strh));
					elem.text = ui.textInput(Id.handle().nest(id, {text: elem.text}), "Text", Right);
					// elem.anchor = ui.combo(Id.handle().nest(id), ["None", "Top-Left", "Top-Center", "Top-Right"], "Anchor", true, Right);
					elem.anchor = ui.combo(Id.handle().nest(id), ["None"], "Anchor", true, Right);
					var assetPos = ui.combo(Id.handle().nest(id, {position: getAssetIndex(elem.asset)}), getEnumTexts(), "Asset", true, Right);
					elem.asset = getEnumTexts()[assetPos];
					elem.color = Ext.colorWheel(ui, Id.handle().nest(id, {color: 0xffffff}), true, null, true);
				}
			}

			ui.separator();

			if (ui.panel(Id.handle({selected: true}), "ASSETS")) {
				if (canvas.assets.length > 0) {
					ui.text("(Drag images to canvas)", zui.Zui.Align.Center, 0xff151515);

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
					ui.text("(Drop files here)", zui.Zui.Align.Center, 0xff151515);
					ui.text("(.png .jpg .hdr)", zui.Zui.Align.Center, 0xff151515);
				}
			}
		}
		ui.end();

		g.begin(false);
		if (dragAsset != null) {
			var ratio = 128 / getImage(dragAsset).width;
			var h = getImage(dragAsset).height * ratio;
			g.drawScaledImage(getImage(dragAsset), ui.inputX, ui.inputY, 128, h);
		}
		g.end();
	}

	function getImage(asset:TAsset):kha.Image {
		return Canvas.assetMap.get(asset.id);
	}

	function removeSelectedElem() {
		canvas.elements.splice(selectedElem, 1);
		if (selectedElem == canvas.elements.length) selectedElem--;
		else if (selectedElem < 0) selectedElem++;
		hradio.position = selectedElem;
	}

	function acceptDrag(index:Int) {
		var elem = makeElem(ElementType.Image);
		elem.asset = assetNames[index];
		elem.x = ui.inputX - canvas.x;
		elem.y = ui.inputY - canvas.y;
		elem.width = getImage(canvas.assets[index]).width;
		elem.height = getImage(canvas.assets[index]).height;
		canvas.elements.push(elem);
		hradio.position = canvas.elements.length - 1;
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
			while (--i >= 0) {
				var elem = canvas.elements[i];
				if (ui.inputX > canvas.x + elem.x && ui.inputX < canvas.x + elem.x + elem.width &&
					ui.inputY > canvas.y + elem.y && ui.inputY < canvas.y + elem.y + elem.height &&
					selectedElem != i) {
					selectedElem = hradio.position = i;
					break;
				}
			}
		}

		if (selectedElem >= 0 && selectedElem < canvas.elements.length) {
			var elem = canvas.elements[selectedElem];

			// Drag selected elem
			if (ui.inputStarted &&
				ui.inputX >= canvas.x + elem.x - 3 && ui.inputX <= canvas.x + elem.x + elem.width + 3 &&
				ui.inputY >= canvas.y + elem.y - 3 && ui.inputY <= canvas.y + elem.y + elem.height + 3) {
				drag = true;
				dragLeft = dragRight = dragTop = dragBottom = false;
				if (ui.inputX > canvas.x + elem.x + elem.width - 3) dragRight = true;
				else if (ui.inputX < canvas.x + elem.x + 3) dragLeft = true;
				if (ui.inputY > canvas.y + elem.y + elem.height - 3) dragBottom = true;
				else if (ui.inputY < canvas.y + elem.y + 3) dragTop = true;

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
			if (ui.isKeyDown) {
				if (ui.key == kha.input.KeyCode.Left) elem.x--;
				if (ui.key == kha.input.KeyCode.Right) elem.x++;
				if (ui.key == kha.input.KeyCode.Up) elem.y--;
				if (ui.key == kha.input.KeyCode.Down) elem.y++;

				if (!ui.isTyping) {
					if (ui.key == kha.input.KeyCode.Backspace || ui.char == "x") removeSelectedElem();
				}

				hwin.redraws = 2;
			}
		}
	}
}
