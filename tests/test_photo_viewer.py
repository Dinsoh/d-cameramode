"""Browser viewer behavior only; does not stand in for inventory or hosting QA."""
from pathlib import Path
from playwright.sync_api import sync_playwright
import base64
with sync_playwright() as p:
    browser=p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,args=['--no-sandbox'])
    page=browser.new_page(viewport={'width':1280,'height':720})
    root=Path(__file__).resolve().parents[1]/'d-photomode/html'
    page.route('http://photomode.test/**',lambda route:route.fulfill(path=str(root/route.request.url.rsplit('/',1)[-1])))
    # Tiny fixture only in this development test; no placeholder photographs ship.
    pixel=base64.b64decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+jRZkAAAAASUVORK5CYII=')
    page.route('https://photos.example.test/**',lambda route:route.fulfill(body=pixel,content_type='image/png'))
    page.goto('http://photomode.test/index.html')
    page.evaluate("() => {window.GetParentResourceName=()=> 'd-photomode'; window.requests=[]; window.fetch=async(url)=>{requests.push(url); return {ok:true,json:async()=>({ok:true})};};}")
    def photo(**changes):
        item=dict(id='fixture-photo', url='https://photos.example.test/test.jpg', caption='<img src=x onerror=alert(1)>',photographer='Test Player',takenAt='2026-10-18T13:00:00Z',public=True)
        item.update(changes)
        page.evaluate("photo=>window.postMessage({action:'photo',photo},'*')",item)
    photo(); page.locator('#photoViewer').wait_for(state='visible')
    assert page.locator('#photoCaption').inner_text()=='<img src=x onerror=alert(1)>'
    assert page.locator('#photoCaption img').count()==0
    for viewport in [{'width':1280,'height':720},{'width':2560,'height':1080},{'width':800,'height':600}]:
        page.set_viewport_size(viewport)
        bounds=page.locator('.polaroid').bounding_box()
        assert bounds['y']>=0 and bounds['y']+bounds['height']<=viewport['height']
    page.evaluate("() => Object.defineProperty(navigator,'clipboard',{configurable:true,value:{writeText:async value=>{window.copied=value}}})")
    page.locator('#photoCopy').click()
    page.wait_for_function("document.getElementById('photoCopyStatus').textContent==='Image link copied.'")
    assert page.evaluate('copied')=='https://photos.example.test/test.jpg'
    page.evaluate("() => Object.defineProperty(navigator,'clipboard',{configurable:true,value:undefined})")
    page.locator('#photoCopy').click(); page.locator('#photoFallback').wait_for(state='visible')
    assert page.locator('#photoLink').input_value()=='https://photos.example.test/test.jpg'
    page.keyboard.press('Escape'); page.locator('#photoViewer').wait_for(state='hidden')
    assert page.locator('#photoImage').get_attribute('src') is None
    assert page.evaluate("requests.some(url=>url.endsWith('/closePhoto'))")
    photo(public=False); page.locator('#photoViewer').wait_for(state='visible')
    assert page.locator('#photoCopy').is_hidden() and page.locator('#photoPublicNotice').is_hidden()
    page.evaluate("window.postMessage({action:'closePhoto'},'*')");page.locator('#photoViewer').wait_for(state='hidden')
    photo(url='javascript:alert(1)'); page.wait_for_timeout(50); assert page.locator('#photoViewer').is_hidden()
    photo();page.locator('#photoViewer').wait_for(state='visible')
    page.set_viewport_size({'width':1280,'height':720})
    page.screenshot(path='/workspace/polaroid-viewer.png',omit_background=True)
    browser.close()
    print('PASS: viewer layout, plain-text caption, link copy, clipboard fallback, Escape cleanup, private-link controls, unsafe URL rejection')
