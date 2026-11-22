// progress-window.js - a small window with a progress bar, fed by a run's
// progress file. Run by a recipe through:
//   osascript -l JavaScript progress-window.js <progress-file> <title> [test]
//
// It only reads the progress file. It shows how many files are done, a bar
// and about how long is left, floats above other windows without taking the
// keyboard, and closes itself a few seconds after the run finishes or stops.
// Its Stop button asks the run to stop (TERM: a run started in the background
// ignores the interrupt signal Ctrl-C sends, so that one cannot be used); the run
// finishes nothing half-way, keeps what is done and can be started again.
// With a third argument it builds the window, reads the file once and
// returns what it would show, without putting anything on screen (tests);
// if that argument is "stop" it also presses Stop.
ObjC.import('Cocoa');

var stopRequested = false;
ObjC.registerSubclass({
    name: 'ImageTransformStopHandler',
    methods: {
        'stop:': { types: ['void', ['id']], implementation: function (sender) { stopRequested = true; } }
    }
});

function sendStop(pid) {
    if (!/^[0-9]+$/.test(pid || '')) return false;
    var ca = Application.currentApplication();
    ca.includeStandardAdditions = true;
    try { ca.doShellScript('kill -TERM ' + pid); return true; } catch (e) { return false; }
}

function readStatus(path) {
    var s = $.NSString.stringWithContentsOfFileEncodingError($(path), $.NSUTF8StringEncoding, null);
    if (s.isNil()) return null;
    var o = {};
    ObjC.unwrap(s).split('\n').forEach(function (line) {
        var i = line.indexOf('=');
        if (i > 0) o[line.slice(0, i)] = line.slice(i + 1);
    });
    return (o.state && o.total) ? o : null;
}

function dur(sec) {
    sec = parseInt(sec, 10);
    if (isNaN(sec)) return '';
    if (sec >= 3600) return Math.floor(sec / 3600) + 'h' + ('0' + Math.floor((sec % 3600) / 60)).slice(-2) + 'm';
    if (sec >= 60) return Math.floor(sec / 60) + 'm' + ('0' + (sec % 60)).slice(-2) + 's';
    return sec + 's';
}

function alive(pid) {
    if (!/^[0-9]+$/.test(pid || '')) return true;
    var ca = Application.currentApplication();
    ca.includeStandardAdditions = true;
    try { ca.doShellScript('kill -0 ' + pid); return true; } catch (e) { return false; }
}

function texts(st) {
    var done = parseInt(st.done, 10) || 0, total = parseInt(st.total, 10) || 0;
    var counts = (parseInt(st.verified, 10) || 0) + (parseInt(st.converted, 10) || 0) + ' converted, ' +
        (parseInt(st.exists, 10) || 0) + ' already existed, ' +
        (parseInt(st.collision, 10) || 0) + ' in a collision, ' + (parseInt(st.failed, 10) || 0) + ' failed';
    var top, bottom = counts;
    if (st.state === 'done') {
        top = 'Finished: ' + done + ' of ' + total + ' in ' + dur(st.elapsed_seconds);
    } else if (st.state === 'running') {
        top = done + ' of ' + total + ' done' + (st.eta_seconds ? ', about ' + dur(st.eta_seconds) + ' left' : '');
        if (st.current) bottom = counts + '  •  ' + st.current;
    } else {
        top = 'Stopped at ' + done + ' of ' + total + '. Ask for the same conversion again to carry on.';
    }
    return { top: top, bottom: bottom, fraction: total > 0 ? done / total : 0 };
}

function run(argv) {
    var path = argv[0], title = argv[1] || 'Converting images', test = argv[2] || '';
    var app = $.NSApplication.sharedApplication;
    app.setActivationPolicy($.NSApplicationActivationPolicyAccessory);

    var win = $.NSWindow.alloc.initWithContentRectStyleMaskBackingDefer(
        $.NSMakeRect(0, 0, 520, 140), $.NSWindowStyleMaskTitled, $.NSBackingStoreBuffered, false);
    win.title = $(title);
    win.level = $.NSFloatingWindowLevel;
    win.center;
    var top = $.NSTextField.labelWithString($('Starting…'));
    top.setFrame($.NSMakeRect(20, 106, 480, 20));
    var bar = $.NSProgressIndicator.alloc.initWithFrame($.NSMakeRect(20, 80, 480, 20));
    bar.indeterminate = false; bar.minValue = 0; bar.maxValue = 1; bar.doubleValue = 0;
    var bottom = $.NSTextField.labelWithString($(''));
    bottom.setFrame($.NSMakeRect(20, 54, 480, 18));
    bottom.font = $.NSFont.systemFontOfSize(11);
    bottom.textColor = $.NSColor.secondaryLabelColor;
    bottom.lineBreakMode = $.NSLineBreakByTruncatingMiddle;
    win.contentView.addSubview(top);
    win.contentView.addSubview(bar);
    win.contentView.addSubview(bottom);
    var handler = $.ImageTransformStopHandler.alloc.init;
    var stop = $.NSButton.buttonWithTitleTargetAction($('Stop'), handler, 'stop:');
    stop.setFrame($.NSMakeRect(410, 12, 96, 32));
    win.contentView.addSubview(stop);
    var asked = false;
    function handleStop(st) {
        if (!stopRequested || asked) return;
        asked = true;
        stop.enabled = false;
        stop.title = $('Stopping\u2026');
        sendStop(st ? st.pid : '');
    }

    function show(st) {
        var t = texts(st);
        top.stringValue = $(t.top); bottom.stringValue = $(t.bottom); bar.doubleValue = t.fraction;
        return t;
    }
    function pump(seconds) {
        var until = $.NSDate.dateWithTimeIntervalSinceNow(seconds);
        while (true) {
            var e = app.nextEventMatchingMaskUntilDateInModeDequeue(0xFFFFFFFF, until, $.NSDefaultRunLoopMode, true);
            if (e.isNil()) break;
            app.sendEvent(e);
        }
    }

    if (test !== '') {
        var once = readStatus(path);
        if (!once) return 'no status';
        var t = show(once);
        var extra = '';
        if (test === 'stop') {
            handler.performSelectorWithObject('stop:', stop);
            handleStop(once);
            extra = ' | button: ' + ObjC.unwrap(stop.title) + ' | stop sent: ' + asked;
        }
        return t.top + ' | ' + t.bottom + ' | ' + Math.round(t.fraction * 100) + '%' + extra;
    }

    win.orderFrontRegardless;
    var started = Date.now(), lastAliveCheck = 0;
    while (true) {
        var st = readStatus(path);
        if (st) {
            if (st.state === 'running' && Date.now() - lastAliveCheck > 3000) {
                lastAliveCheck = Date.now();
                if (!alive(st.pid)) st.state = 'stopped';
            }
            show(st);
            if (st.state !== 'running') break;
            handleStop(st);
        } else if (Date.now() - started > 15000) {
            break;                      // no readable progress file: give up quietly
        }
        pump(0.4);
    }
    stop.enabled = false;
    pump(4);                            // leave the final line up for a moment
    win.close;
    return '';
}
