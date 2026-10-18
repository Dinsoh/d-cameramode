from pathlib import Path
from playwright.sync_api import sync_playwright
with sync_playwright() as p:
    b=p.chromium.launch(executable_path='/usr/bin/chromium',headless=True,args=['--no-sandbox'])
    page=b.new_page(viewport={'width':1920,'height':1080})
    root=Path(__file__).resolve().parents[1]/'d-photomode/html'
    page.route('http://photomode.test/**', lambda route: route.fulfill(path=str(root / (route.request.url.rsplit('/',1)[-1] or 'index.html'))))
    page.goto('http://photomode.test/index.html')
    page.evaluate("() => { window.GetParentResourceName=()=> 'd-photomode'; window.calls=[]; window.fetch=async (url,opts)=>{calls.push([url,JSON.parse(opts.body)]);return {ok:true,json:async()=>({ok:true})}}; }")
    page.evaluate("window.postMessage({action:'open',fov:{min:20,max:80,default:50},tilt:15,filters:[{label:'Natural'},{label:'Soft'}],dof:true,hideKey:'H'},'*')")
    page.locator('#panel').wait_for(state='visible')
    page.locator('#fov').fill('35'); page.locator('#fov').dispatch_event('input'); page.wait_for_timeout(150)
    assert page.evaluate("calls.some(c=>c[0].endsWith('/update')&&c[1].fov===35)")
    page.locator('#showGrid').check(); assert page.locator('#grid').is_visible()
    page.locator('#reset').click(); assert page.locator('#fov').input_value()=='50'; assert not page.locator('#grid').is_visible()
    page.keyboard.press('h'); assert page.evaluate("calls.some(c=>c[0].endsWith('/hide'))")
    page.evaluate("window.postMessage({action:'hidden',hidden:true},'*')"); page.locator('#frame').wait_for(state='hidden')
    page.evaluate("window.postMessage({action:'hidden',hidden:false},'*')"); page.locator('#frame').wait_for(state='visible')
    page.keyboard.press('Escape'); assert page.evaluate("calls.some(c=>c[0].endsWith('/close'))")
    page.evaluate("window.postMessage({action:'open',fov:{min:20,max:80,default:50},tilt:15,filters:[{label:'Natural'}],dof:false,hideKey:'H',orbit:{distance:{min:1,max:3,default:2},height:{min:-0.4,max:1.5,default:0.2}}},'*')")
    page.locator('#orbit').wait_for(state='visible')
    page.locator('[data-angle="180"]').click(); page.wait_for_timeout(150)
    assert page.evaluate("calls.some(c=>c[0].endsWith('/update')&&c[1].angle===180)")
    page.locator('#distance').fill('2.5'); page.locator('#distance').dispatch_event('input'); page.wait_for_timeout(150)
    assert page.evaluate("calls.some(c=>c[1].distance===2.5)")
    page.locator('#reset').click(); assert page.locator('#angle').input_value()=='0'; assert page.locator('#distance').input_value()=='2'
    page.set_viewport_size({'width':1280,'height':720})
    bounds=page.locator('#panel').bounding_box(); assert bounds['y']>=0 and bounds['y']+bounds['height']<=720
    page.screenshot(path='/workspace/photomode-ui.png',omit_background=True)
    page.evaluate("window.postMessage({action:'close'},'*')"); page.locator('#frame').wait_for(state='hidden')
    print('PASS: UI open/update, grid, reset, hide/restore, exit, 720p fit, close')
    b.close()
