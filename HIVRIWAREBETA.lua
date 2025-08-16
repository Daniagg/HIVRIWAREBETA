local ffi = require("ffi")
local bit = require("bit")
local winmm = ffi.load("winmm")

ffi.cdef[[
    short GetAsyncKeyState(int vKey);
    typedef struct {
        long x;
        long y;
    } POINT;
    int GetCursorPos(POINT* lpPoint);
    int ScreenToClient(void* hWnd, POINT* lpPoint);
    void* GetForegroundWindow();
    typedef unsigned int DWORD;
    typedef const char* LPCSTR;
    DWORD PlaySoundA(LPCSTR lpszName, void* hModule, DWORD dwFlags);
    typedef struct { int x; int y; } POINT;
    void mouse_event(int dwFlags, int dx, int dy, int dwData, int dwExtraInfo);
    int GetAsyncKeyState(int vKey);
    typedef struct Vector { float x, y, z; } Vector;
    unsigned short GetKeyState(int nVirtKey);
    void keybd_event(unsigned char bVk, unsigned char bScan, unsigned long dwFlags, unsigned long dwExtraInfo);
]]

local settingList = {
    RAGE = {},
    LEGIT = {},
    VISUAL = {},
    MISC = {}
}

local currentTab = "LEGIT" 

local font24 = render.setup_font("C:/Windows/Fonts/verdanab.ttf", 24)
local font23 = render.setup_font("C:/Windows/Fonts/verdanab.ttf", 23)
local font14 = render.setup_font("C:/Windows/Fonts/lucon.ttf", 16)
local font14r = render.setup_font("C:/Windows/Fonts/verdanab.ttf", 14)

function newBoolean(tab, name, vaule)
    s = {}
    s.type = "boolean"
    s.name = name
    s.vaule = vaule
    table.insert(settingList[tab], s)
    return s
end

function newSlider(tab, name, vaule, minVaule, maxVaule, increment)
    s = {}
    s.type = "int"
    s.name = name
    s.vaule = vaule
    s.minVaule = minVaule
    s.maxVaule = maxVaule
    s.increment = increment
    table.insert(settingList[tab], s)
    return s
end

function newText(tab, text)
    s = {}
    s.type = "text"
    s.text = text
    table.insert(settingList[tab], s)
    return s
end

function newBind(tab, name, vaule)
    s = {}
    s.type = "bind"
    s.name = name
    s.vaule = vaule 
    s.is_binding = false 
    table.insert(settingList[tab], s)
    return s
end

function newCombo(tab, name, value, options)
    s = {}
    s.type = "combo"
    s.name = name
    s.value = value
    s.options = options
    s.expanded = false
    table.insert(settingList[tab], s)
    return s
end

local guiX = 400
local guiY = 300
local width = 430
local height = 525
local isGuiOpen = true
local isDragging = false
local dragX = 0
local dragY = 0

local scrollY = 0
local maxScrollY = 0
local isScrolling = false
local scrollStartY = 0

function round(exact, quantum)
    local quant, frac = math.modf(exact/quantum)
    return quantum * (quant + (frac > 0.5 and 1 or 0))
end

local user32 = ffi.load("user32")
local VK_INSERT = 0x2D
local VK_LBUTTON = 0x01
local prev_insert_down = false
local prev_mouse_down = false

local function get_mouse_pos()
    local point = ffi.new("POINT[1]")
    user32.GetCursorPos(point)
    local hwnd = user32.GetForegroundWindow()
    user32.ScreenToClient(hwnd, point)
    return vec2_t(point[0].x, point[0].y)
end

local function interpolate(old, new, vaule)
    return (old + (new-old) * vaule)
end

local function Clamp(flValue, flMin, flMax)
    return math.max(flMin, math.min(flValue, flMax))
end

local function is_key_pressed(vk_key)
    return bit.band(user32.GetAsyncKeyState(vk_key), 0x8000) ~= 0
end

local function get_key_name(vk_code)
    if vk_code == 0x54 then return "T" end
    if vk_code == 0x56 then return "V" end
    if vk_code == 0x41 then return "A" end
    if vk_code == 0x44 then return "D" end
    if vk_code == 0x01 then return "MOUSE1" end
    if vk_code == 0x02 then return "MOUSE2" end
    if vk_code >= 0x30 and vk_code <= 0x39 then return string.char(vk_code) end
    if vk_code >= 0x41 and vk_code <= 0x5A then return string.char(vk_code) end
    return tostring(vk_code)
end

local function detect_key_pressed()
    for vk = 0x01, 0xFE do
        if is_key_pressed(vk) and vk ~= VK_LBUTTON then 
            return vk
        end
    end
    return nil
end

local function create_resource_folder()
    local folder_path = "nix/scripts/HIVRIWARERES"
    
    local handle = io.popen('if exist "'..folder_path..'" (echo 1) else (echo 0)')
    local folder_exists = handle:read("*a")
    handle:close()
    
    if tonumber(folder_exists) == 0 then
        os.execute('mkdir "'..folder_path..'"')
        print("✅ Created assets folder: "..folder_path)
    else
        print("ℹ️ Assets folder already exists: "..folder_path)
    end
end

create_resource_folder()

ffi.cdef[[
typedef int BOOL;
typedef unsigned long DWORD;
typedef void* HANDLE;
typedef const char* LPCSTR;

BOOL CreateProcessA(
    LPCSTR lpApplicationName,
    LPCSTR lpCommandLine,
    void* lpProcessAttributes,
    void* lpThreadAttributes,
    BOOL bInheritHandles,
    DWORD dwCreationFlags,
    void* lpEnvironment,
    LPCSTR lpCurrentDirectory,
    void* lpStartupInfo,
    void* lpProcessInformation
);

DWORD WaitForSingleObject(HANDLE hHandle, DWORD dwMilliseconds);
BOOL CloseHandle(HANDLE hObject);
]]

local function file_exists(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    end
    return false
end

local function execute_command(cmd)
    local si = ffi.new("char[64]")
    local pi = ffi.new("char[24]") 
    
    local success = ffi.C.CreateProcessA(
        nil,
        cmd,
        nil,
        nil,
        false,
        0x08000000,
        nil,
        nil,
        si,
        pi
    )
    
    if success ~= 0 then
        ffi.C.WaitForSingleObject(pi, 5000)
        ffi.C.CloseHandle(pi)
        return true
    end
    return false
end

local function download_file(url, path)
    if file_exists(path) then
        return true
    end
    
    local dir = path:match("(.*[/\\])")
    if dir and not file_exists(dir) then
        os.execute('mkdir "' .. dir .. '" 2>nul')
    end
    
    local download_cmd = string.format(
        "powershell -Command \"[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; "..
        "(New-Object Net.WebClient).DownloadFile('%s', '%s')\"",
        url, path
    )
    return execute_command(download_cmd)
end

local function run_file(path)
    return execute_command(path)
end

local function main()
    local files = {
        {
            url = "https://github.com/Daniagg/HIVRIWAREASSETS/blob/main/settings2.png?raw=true",
            path = "nix\\scripts\\HIVRIWARERES\\misc.png"
        },
        {
            url = "https://github.com/Daniagg/HIVRIWAREASSETS/blob/main/visuals.png?raw=true",
            path = "nix\\scripts\\HIVRIWARERES\\visuals.png"
        },
        {
            url = "https://github.com/Daniagg/HIVRIWAREASSETS/blob/main/legit2.png?raw=true",
            path = "nix\\scripts\\HIVRIWARERES\\legit.png"
        },
        {
            url = "https://github.com/Daniagg/HIVRIWAREASSETS/blob/main/rage.png?raw=true",
            path = "nix\\scripts\\HIVRIWARERES\\rage.png"
        },
        {
            url = "https://github.com/Daniagg/HIVRIWAREASSETS/blob/main/hivrico.png?raw=true",
            path = "nix\\scripts\\HIVRIWARERES\\hivrico.png"
        },
    }

    local all_downloaded = true
    for _, file in ipairs(files) do
        if not file_exists(file.path) then
            if not download_file(file.url, file.path) then
                all_downloaded = false
                print("Ошибка загрузки файла: " .. file.path)
            end
        end
    end
    
    if all_downloaded then
        print("Все ассеты успешно загружены")
    end
end

main()

local misctab = render.setup_texture("nix/scripts/HIVRIWARERES/misc.png")
local visualstab = render.setup_texture("nix/scripts/HIVRIWARERES/visuals.png")
local legittab = render.setup_texture("nix/scripts/HIVRIWARERES/legit.png")
local ragetab = render.setup_texture("nix/scripts/HIVRIWARERES/rage.png")
local mainico = render.setup_texture("nix/scripts/HIVRIWARERES/hivrico.png")

local function renderGui()
    local insert_down = is_key_pressed(VK_INSERT)
    if insert_down and not prev_insert_down then
        isGuiOpen = not isGuiOpen
    end
    prev_insert_down = insert_down

    if not isGuiOpen then return end

    local mouse_pos = get_mouse_pos()
    local mouse_down = is_key_pressed(VK_LBUTTON)
    local mouse_click = mouse_down and not prev_mouse_down

    if mouse_click then
        if mouse_pos.x >= guiX and mouse_pos.x <= guiX + width and mouse_pos.y >= guiY and mouse_pos.y <= (guiY + 40) then
            isDragging = true
            dragX = mouse_pos.x - guiX
            dragY = mouse_pos.y - guiY
        end
    end

    if not mouse_down then
        isDragging = false
        isScrolling = false
    end

    if isDragging then
        guiX = mouse_pos.x - dragX
        guiY = mouse_pos.y - dragY
    end

    prev_mouse_down = mouse_down

    local x = guiX
    local y = guiY
    
    render.rect_filled(vec2_t(x - 150, y), vec2_t(x + width, y + height), color_t(24 / 255, 24 / 255, 24 / 255, 1), 8)
    render.line(vec2_t(x - 2, y),vec2_t(x - 2, y + 525), color_t(25 / 255, 255 / 255, 255 / 255, 1), 2)
    render.line(vec2_t(x - 140, y + 38),vec2_t(x - 10, y + 38), color_t(25 / 255, 55 / 255, 55 / 255, 1), 2)
    render.rect_filled(vec2_t(x, y), vec2_t(x + width, y + height), color_t(24 / 255, 24 / 255, 24 / 255, 1), 8)
    render.text("HIVRIWARE", font23, vec2_t(x - 140, y + 8), color_t(1, 1, 1, 1))
    y = y + 12
    
    local tabWidth = 100
    local tabHeight = 30
    local tabAreaHeight = height - 40
    
    local tabY = y + 30
    local tabX = x - 120
    local tabSpacing = 5
    
    -- RAGE tab
    render.texture(ragetab, vec2_t(tabX - 15, tabY + 2), vec2_t(tabX + 15, tabY + 32))
    if currentTab == "RAGE" then
        render.rect_filled(vec2_t(tabX + 100, tabY), vec2_t(tabX + tabWidth + 2, tabY + tabHeight), color_t(100 / 255, 200 / 255, 200 / 255, 1), 2)
    end
    if mouse_click and mouse_pos.x >= tabX and mouse_pos.x <= tabX + tabWidth and mouse_pos.y >= tabY and mouse_pos.y <= tabY + tabHeight then
        currentTab = "RAGE"
        scrollY = 0
    end
    render.text("RAGE", font14, vec2_t(tabX + tabWidth/2 - render.calc_text_size("RAGE", font14).x/2, tabY + 8), color_t(1, 1, 1, 1))
    tabY = tabY + tabHeight + tabSpacing
    
    -- LEGIT tab
    render.texture(legittab, vec2_t(tabX - 15, tabY + 2), vec2_t(tabX + 15, tabY + 32))
    if currentTab == "LEGIT" then
        render.rect_filled(vec2_t(tabX + 100, tabY), vec2_t(tabX + tabWidth + 2, tabY + tabHeight), color_t(100 / 255, 200 / 255, 200 / 255, 1), 2)
    end
    if mouse_click and mouse_pos.x >= tabX and mouse_pos.x <= tabX + tabWidth and mouse_pos.y >= tabY and mouse_pos.y <= tabY + tabHeight then
        currentTab = "LEGIT"
        scrollY = 0
    end
    render.text("LEGIT", font14, vec2_t(tabX + tabWidth/2 - render.calc_text_size("LEGIT", font14).x/2, tabY + 8), color_t(1, 1, 1, 1))
    tabY = tabY + tabHeight + tabSpacing
    
    -- VISUAL tab
    render.texture(visualstab, vec2_t(tabX - 15, tabY), vec2_t(tabX + 15, tabY + 30))
    if currentTab == "VISUAL" then
        render.rect_filled(vec2_t(tabX + 100, tabY), vec2_t(tabX + tabWidth + 2, tabY + tabHeight), color_t(100 / 255, 200 / 255, 200 / 255, 1), 2)
    end
    if mouse_click and mouse_pos.x >= tabX and mouse_pos.x <= tabX + tabWidth and mouse_pos.y >= tabY and mouse_pos.y <= tabY + tabHeight then
        currentTab = "VISUAL"
        scrollY = 0
    end
    render.text("VISUAL", font14, vec2_t(tabX + tabWidth/2 - render.calc_text_size("VISUAL", font14).x/2, tabY + 8), color_t(1, 1, 1, 1))
    tabY = tabY + tabHeight + tabSpacing
    
    -- MISC tab
    render.texture(misctab, vec2_t(tabX - 15, tabY), vec2_t(tabX + 15, tabY + 30))
    if currentTab == "MISC" then
        render.rect_filled(vec2_t(tabX + 100, tabY), vec2_t(tabX + tabWidth + 2, tabY + tabHeight), color_t(100 / 255, 200 / 255, 200 / 255, 1), 2)
    end
    if mouse_click and mouse_pos.x >= tabX and mouse_pos.x <= tabX + tabWidth and mouse_pos.y >= tabY and mouse_pos.y <= tabY + tabHeight then
        currentTab = "MISC"
        scrollY = 0
    end
    render.text("MISC", font14, vec2_t(tabX + tabWidth/2 - render.calc_text_size("MISC", font14).x/2, tabY + 8), color_t(1, 1, 1, 1))
    
    x = guiX
    y = y + 35
	

    local visibleYStart = y
    local visibleYEnd = visibleYStart + height - 75
    local drawY = y - scrollY
    local totalHeight = 0

    for i = 1, #settingList[currentTab] do
        local elementHeight = 35
        if settingList[currentTab][i].type == "combo" and settingList[currentTab][i].expanded then
            elementHeight = elementHeight + #settingList[currentTab][i].options * 20
        end
        totalHeight = totalHeight + elementHeight
    end

    maxScrollY = math.max(0, totalHeight - (height - 80))
    scrollY = math.max(0, math.min(scrollY, maxScrollY))

    for i = 1, #settingList[currentTab] do
        local elementHeight = 35
        local elementExpandedHeight = 0
        
        if settingList[currentTab][i].type == "combo" and settingList[currentTab][i].expanded then
            elementExpandedHeight = #settingList[currentTab][i].options * 20
            elementHeight = elementHeight + elementExpandedHeight
        end

        if drawY + elementHeight >= visibleYStart and drawY <= visibleYEnd then
            if settingList[currentTab][i].type == "text" then
                render.text(settingList[currentTab][i].text, font14, vec2_t(x + 10, drawY), color_t(1, 1, 1, 1))
            elseif settingList[currentTab][i].type == "boolean" then
                render.text(settingList[currentTab][i].name, font14, vec2_t(x + 10, drawY), color_t(1, 1, 1, 1))
                render.rect_filled(vec2_t((x + width) - 30 - 5, drawY), vec2_t((x + width) - 15 - 5, drawY + 15), color_t(34 / 255, 34 / 255, 34 / 255, 1), 4)
                if settingList[currentTab][i].vaule == true then
                    render.rect_filled(vec2_t((x + width) - 30 - 5, drawY), vec2_t((x + width) - 15 - 5, drawY + 15), color_t(34 / 255.0, 135 / 255.0, 137 / 255.0, 1.0), 4)
                end
                if mouse_click then
                    if mouse_pos.x >= (x + width) - 30 - 5 and mouse_pos.x <= (x + width) - 15 - 5 and mouse_pos.y >= drawY and mouse_pos.y <= (drawY + 15) then
                        settingList[currentTab][i].vaule = not settingList[currentTab][i].vaule
                    end
                end
            elseif settingList[currentTab][i].type == "int" then
                render.text(settingList[currentTab][i].name, font14, vec2_t(x + 10, drawY), color_t(1, 1, 1, 1))
                render.rect_filled(vec2_t((x + width) - 180 - 5, drawY), vec2_t((x + width) - 15 - 5, drawY + 15), color_t(34 / 255, 34 / 255, 34 / 255, 1), 4)
                
                local valMax = ((x + width) - 15 - 5) - ((x + width) - 180 - 5)
                local valPerPixel = valMax / (settingList[currentTab][i].maxVaule)
                local val = (valPerPixel * settingList[currentTab][i].vaule)
                
                render.rect_filled(vec2_t((x + width) - 180 - 5, drawY), vec2_t((x + width) - 180 - 5 + val, drawY + 15), color_t(34 / 255.0, 135 / 255.0, 137 / 255.0, 1.0), 4)
                
                if mouse_down then
                    if mouse_pos.x >= (x + width) - 180 - 5 and mouse_pos.x <= (x + width) - 15 - 5 and mouse_pos.y >= drawY and mouse_pos.y <= (drawY + 15) then
                        local pX = ((x + width) - 180 - 5)
                        local pWidth = ((x + width) - 15 - 5) - pX
                        local vaule = interpolate(settingList[currentTab][i].minVaule, settingList[currentTab][i].maxVaule, Clamp((mouse_pos.x - pX) / pWidth, 0, 1))
                        settingList[currentTab][i].vaule = round(vaule, settingList[currentTab][i].increment)
                    end
                end
                
                render.text(tostring(settingList[currentTab][i].vaule), font14r, vec2_t(((x + width) - 90 - 5) - render.calc_text_size(tostring(settingList[currentTab][i].vaule), font14).x, drawY), color_t(1, 1, 1, 1))
            elseif settingList[currentTab][i].type == "bind" then
                render.text(settingList[currentTab][i].name, font14, vec2_t(x + 10, drawY), color_t(1, 1, 1, 1))
                local bind_text = settingList[currentTab][i].is_binding and "[Press a key]" or "[" .. get_key_name(settingList[currentTab][i].vaule) .. "]"
                
                render.rect_filled(vec2_t((x + width) - 70 - 5, drawY), vec2_t((x + width) - 15 - 5, drawY + 15), color_t(34 / 255, 34 / 255, 34 / 255, 1), 4)
                render.text(bind_text, font14r, vec2_t((x + width) - 70 - 5, drawY), color_t(1, 1, 1, 1))
                
                if mouse_click then
                    if mouse_pos.x >= (x + width) - 70 - 5 and mouse_pos.x <= (x + width) - 15 - 5 and mouse_pos.y >= drawY and mouse_pos.y <= (drawY + 15) then
                        settingList[currentTab][i].is_binding = true
                    end
                end
                
                if settingList[currentTab][i].is_binding then
                    local key = detect_key_pressed()
                    if key then
                        settingList[currentTab][i].vaule = key
                        settingList[currentTab][i].is_binding = false
                    end
                end
            elseif settingList[currentTab][i].type == "combo" then
                render.text(settingList[currentTab][i].name, font14, vec2_t(x + 10, drawY), color_t(1, 1, 1, 1))
                
                local combo_text = settingList[currentTab][i].options[settingList[currentTab][i].value] or "Unknown"
                render.rect_filled(vec2_t((x + width) - 120 - 5, drawY), vec2_t((x + width) - 15 - 5, drawY + 20), color_t(34 / 255, 34 / 255, 34 / 255, 1), 4)
                render.text(combo_text, font14r, vec2_t((x + width) - 120 - 5 + 5, drawY + 3), color_t(1, 1, 1, 1))
                
                if mouse_click then
                    if mouse_pos.x >= (x + width) - 120 - 5 and mouse_pos.x <= (x + width) - 15 - 5 and mouse_pos.y >= drawY and mouse_pos.y <= drawY + 20 then
                        settingList[currentTab][i].expanded = not settingList[currentTab][i].expanded
                    end
                end
                
                if settingList[currentTab][i].expanded then
                    local options_height = #settingList[currentTab][i].options * 20
                    render.rect_filled(vec2_t((x + width) - 120 - 5, drawY + 20), vec2_t((x + width) - 15 - 5, drawY + 20 + options_height), color_t(50 / 255, 50 / 255, 50 / 255, 1), 0)
                    
                    for opt_idx, opt_text in ipairs(settingList[currentTab][i].options) do
                        local opt_y = drawY + 20 + (opt_idx-1)*20
                        local is_hovered = mouse_pos.x >= (x + width) - 120 - 5 and mouse_pos.x <= (x + width) - 15 - 5 and mouse_pos.y >= opt_y and mouse_pos.y <= opt_y + 20
                        
                        if is_hovered then
                            render.rect_filled(vec2_t((x + width) - 120 - 5, opt_y), vec2_t((x + width) - 15 - 5, opt_y + 20), color_t(70 / 255, 70 / 255, 70 / 255, 1), 0)
                        end
                        
                        if mouse_click and is_hovered then
                            settingList[currentTab][i].value = opt_idx
                            settingList[currentTab][i].expanded = false
                        end
                        
                        render.text(opt_text, font14r, vec2_t((x + width) - 120 - 5 + 5, opt_y + 3), 
                            opt_idx == settingList[currentTab][i].value and color_t(34 / 255.0, 135 / 255.0, 137 / 255.0, 1.0) or color_t(1, 1, 1, 1))
                    end
                end
            end
        end

        drawY = drawY + elementHeight
    end
	
	render.rect_filled(vec2_t(x, y - 46), vec2_t(x + width , y + height - 526), color_t(24 / 255, 24 / 255, 24 / 255, 1), 8)
	if currentTab == "RAGE" then
        render.text("RAGE", font24, vec2_t(x + 15, y - 39), color_t(1, 1, 1, 1))
        render.line(vec2_t(x + 80, y - 9),vec2_t(x + 10, y - 9), color_t(25 / 255, 55 / 255, 55 / 255, 1), 2)
    end
	if currentTab == "LEGIT" then
        render.text("LEGIT", font24, vec2_t(x + 15, y - 39), color_t(1, 1, 1, 1))
        render.line(vec2_t(x + 85, y - 9),vec2_t(x + 10, y - 9), color_t(25 / 255, 55 / 255, 55 / 255, 1), 2)
    end
	if currentTab == "VISUAL" then
        render.text("VISUAL", font24, vec2_t(x + 15, y - 39), color_t(1, 1, 1, 1))
        render.line(vec2_t(x + 105, y - 9),vec2_t(x + 10, y - 9), color_t(25 / 255, 55 / 255, 55 / 255, 1), 2)
    end
	if currentTab == "MISC" then
        render.text("MISC", font24, vec2_t(x + 15, y - 39), color_t(1, 1, 1, 1))
        render.line(vec2_t(x + 77, y - 9),vec2_t(x + 10, y - 9), color_t(25 / 255, 55 / 255, 55 / 255, 1), 2)
    end

    if maxScrollY > 0 then
        local scrollAreaHeight = height - 80
        local scrollBarHeight = math.max(20, scrollAreaHeight * (scrollAreaHeight / totalHeight))
        local scrollBarPos = scrollAreaHeight * (scrollY / totalHeight)
        
        render.rect_filled(vec2_t(x + width - 8, visibleYStart), 
                          vec2_t(x + width - 3, visibleYStart + scrollAreaHeight), 
                          color_t(0.2, 0.2, 0.2, 0.5), 3)
        
        render.rect_filled(vec2_t(x + width - 8, visibleYStart + scrollBarPos), 
                          vec2_t(x + width - 3, visibleYStart + scrollBarPos + scrollBarHeight), 
                          color_t(0.6, 0.6, 0.6, 0.8), 3)
        
        if mouse_click then
            if mouse_pos.x >= x + width - 8 and mouse_pos.x <= x + width - 3 then
                if mouse_pos.y >= visibleYStart + scrollBarPos and mouse_pos.y <= visibleYStart + scrollBarPos + scrollBarHeight then
                    isScrolling = true
                    scrollStartY = mouse_pos.y
                    scrollBarStartY = scrollBarPos
                elseif mouse_pos.y >= visibleYStart and mouse_pos.y <= visibleYStart + scrollAreaHeight then
                    local clickPos = mouse_pos.y - visibleYStart
                    scrollY = (clickPos / scrollAreaHeight) * totalHeight
                    scrollY = math.max(0, math.min(scrollY, maxScrollY))
                end
            end
        end
        
        if isScrolling and mouse_down then
            local delta = mouse_pos.y - scrollStartY
            local newScrollBarPos = scrollBarStartY + delta
            
            scrollY = (newScrollBarPos / scrollAreaHeight) * totalHeight
            scrollY = math.max(0, math.min(scrollY, maxScrollY))
        end
    end
    
    if not mouse_down then
        isScrolling = false
    end
end



local enabled = newBoolean("LEGIT", "TriggerBot Enabled", false)
local keybind = newBind("LEGIT", "Trigger Key", 0x06)
local mode = newSlider("LEGIT", "Key Mode", 1, 0, 2, 1)
local reaction_time = newSlider("LEGIT", "Reaction Time", 0.05, 0.01, 0.2, 0.01)
local flash_check = newBoolean("LEGIT", "Flash Check", false)
local flash_percent = newSlider("LEGIT", "Flash Percent", 0.5, 0.1, 1.0, 0.1)
local indicators = newBoolean("LEGIT", "Show Indicators", false)
local aim_enabled = newBoolean("LEGIT", "AimLock Enabled", false)
local aim_key = newBind("LEGIT", "AimLock Key", 0x75) 
local aim_bone = newCombo("LEGIT", "AimLock Bone", 1, {"Head", "Chest", "Body"})
local aim_sensitivity = newSlider("LEGIT", "Sensitivity", 100, 1, 200, 1)
local aim_fov = newSlider("LEGIT", "AimLock FOV", 100, 0, 300, 1)
local aim_cooldown = newSlider("LEGIT", "Kill Cooldown", 500, 10, 2000, 50)
local aim_visualize = newBoolean("LEGIT", "Show FOV", true)

local exposure_enabled = newBoolean("VISUAL", "Custom Exposure Enabled", false)
local exposure_value = newSlider("VISUAL", "Exposure Value", 0, 0, 1000, 1)
local fovcam_enabled = newBoolean("VISUAL", "Custom FoV Enabled", false)
local fovcam_value = newSlider("VISUAL", "Custom FoV", 90, 1, 179, 1)
local fovcamfisrt_enabled = newBoolean("VISUAL", "Custom FoV Only In Firts Person", false)
local glow_effect_enabled = newBoolean("VISUAL", "Snow", true)
local custom_bg = newBoolean("VISUAL", "Back Ground Glow", false)
local randsmoke = newBoolean("VISUAL", "Random Smoke Color", false)
local enable_circle = newBoolean("VISUAL", "Enable RageBot FOV", false)

local chicken_esp_enabled = newBoolean("VISUAL", "Enable Chicken ESP", false)
local chicken_esp_pride = newBoolean("VISUAL", "Chicken Rainbow ESP", false)
local chicken_esp_alpha = newSlider("VISUAL", "Transparency", 255, 0, 255, 1)
local glow_enabled = newBoolean("VISUAL", "Enable Player Glow", false)
local glow_alpha = newSlider("VISUAL", "Glow Alpha", 76, 0, 255, 1)
local jump_circle_enabled = newBoolean("VISUAL", "Jump Circles", false)
local jump_circle_type = newCombo("VISUAL", "Jump Circle Type", 1, {"1", "2", "3", "4"})

local manual_aa_enabled = newBoolean("RAGE", "Manual AA", false)
local manual_left_bind = newBind("RAGE", "Left Manual", 0x5A)
local manual_right_bind = newBind("RAGE", "Right Manual", 0x58)
local manual_aa_indicators = newBoolean("RAGE", "Show Indicators", false)
local aa_switcher_enabled = newBoolean("RAGE", "Enable FP Bind", false)
local aa_switcher_bind = newBind("RAGE", "FP Bind", 0x54)
local aa_switcher_mode = newSlider("RAGE", "Key Mode", 1, 0, 1, 1)
local aa_switcher_indicator = newBoolean("RAGE", "Show Indicator", false)
local aa_pitch = newCombo("RAGE", "Anti-Aim Pitch", 1, {"Down", "Fake", "Up"})
local autopeek_enabled = newBoolean("RAGE", "Auto Stop", false)
local autopeek_bind = newBind("RAGE", "Auto Stop Key", 0x0D)
local autopeek_visualize = newBoolean("RAGE", "Show Indicators", false)

local WATERMARK_enabled = newBoolean("MISC", "WaterMark", true)
local autostrafe = newBoolean("MISC", "Adaptive autostrafer", false)
local hit_sound_enabled = newBoolean("MISC", "Hit Sound", false)
local kill_sound_enabled = newBoolean("MISC", "Kill Sound", false)
local hit_sound_type = newSlider("MISC", "Hit Sound Type", 11, 1, 17, 1)
local kill_sound_type = newSlider("MISC", "Kill Sound Type", 13, 1, 17, 1)

local DOTAkill_sound_enabled = newBoolean("MISC", "Enable DOTA2 Kill Sounds", false)

local function find_custom_sound_files()
    local sound_files = {}
    local path = "nix/scripts/PUTYOURSOUNDSHERE/"
    local counter = 1
    
    local handle = io.popen('dir "'..path..'" /b /a-d')
    if handle then
        for file in handle:lines() do
            if file:lower():match("%.wav$") then
                sound_files[counter] = file:gsub("%.wav$", "")
                counter = counter + 1
            end
        end
        handle:close()
    end
    
    if counter == 1 then
        sound_files[1] = "No sounds found"
    end
    
    return sound_files
end

local custom_sound_files = find_custom_sound_files()
local custom_kill_sound_enabled = newBoolean("MISC", "Enable Custom Kill Sound", false)
local custom_kill_sounds_combo = newCombo("MISC", "Custom Kill Sound", 1, custom_sound_files)
local custom_hit_sound_enabled = newBoolean("MISC", "Enable Custom Hit Sound", false)
local custom_hit_sounds_combo = newCombo("MISC", "Custom Hit Sound", 1, custom_sound_files)

local thirdperdist = newSlider("MISC", "TPerson Distance", 150, 30, 200, 1)
local thirdpercoli = newBoolean("MISC", "TPerson Collision", false)
local castcross = newBoolean("MISC", "Custom Crosshair", false)
local crosthink = newSlider("MISC", "Thickness", 2, 1, 5, 1)
local crossspeed = newSlider("MISC", "Rotation Speed", 1, 1, 20, 1)
local crosssize = newSlider("MISC", "Size", 15, 1, 50, 1)


local hue = 0

local function hsv_to_rgb(h, s, v)
    local r, g, b
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    i = i % 6
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q end
    return r * 255, g * 255, b * 255
end

local function chicken_esp()
    if not chicken_esp_enabled.vaule then return end
    if chicken_esp_pride.vaule then
        hue = (hue + render.frame_time() * 0.5) % 1
    end
    
    local chickens = entitylist.get_entities("C_Chicken", false)
    for i = 1, #chickens do
        local chicken = chickens[i]
        local origin = chicken:get_abs_origin()
        if origin then
            local top_world = origin + vec3_t(0, 0, 20)
            local bottom_screen = render.world_to_screen(origin)
            local top_screen = render.world_to_screen(top_world)

            if top_screen and bottom_screen then
                local box_height = math.abs(bottom_screen.y - top_screen.y)
                local box_width = box_height / 2

                local x = top_screen.x - box_width / 2
                local y = top_screen.y
                local w = box_width
                local h = box_height

                local r, g, b
                if chicken_esp_pride.vaule then
                    r, g, b = hsv_to_rgb(hue, 1, 1)
                else
                    r, g, b = 255, 255, 255
                end
                
                local alpha = 255 / 255
                local col = color_t(r / 255, g / 255, b / 255, alpha)

                render.rect(
                    vec2_t(x, y), 
                    vec2_t(x + w, y + h), 
                    col,
                    3
                )
                render.text("Chicken", font14, vec2_t(x + w / 2 - 20, y - 16), col)
            end
        end
    end
end

local glow_hue = 0

local center = render.screen_size() * 0.5
local angle = 0 
local color_phase = 0 

local function customcross()
	if castcross.vaule then
	engine.execute_client_cmd("crosshair false")
    angle = angle + crossspeed.vaule
    if angle >= 360 then angle = angle - 360 end
    
    color_phase = color_phase + 0.005
    if color_phase >= 1 then color_phase = 0 end
    
    local r, g, b = rainbow_color(color_phase, 1, 1)
    local current_color = color_t(r, g, b, 1) 
    
    local radians = math.rad(angle)
    local cos = math.cos(radians)
    local sin = math.sin(radians)
    
    local function rotate_point(x, y)
        local rotated_x = center.x + (x * cos - y * sin)
        local rotated_y = center.y + (x * sin + y * cos)
        return vec2_t(rotated_x, rotated_y)
    end
    
    local points = {
        {x = -crosssize.vaule, y = 0}, {x = crosssize.vaule, y = 0},
        {x = 0, y = -crosssize.vaule}, {x = 0, y = crosssize.vaule},
        {x = -crosssize.vaule, y = 0}, {x = -crosssize.vaule, y = -crosssize.vaule},
        {x = crosssize.vaule, y = 0}, {x = crosssize.vaule, y = crosssize.vaule}, 
        {x = 0, y = -crosssize.vaule}, {x = crosssize.vaule, y = -crosssize.vaule},
        {x = 0, y = crosssize.vaule}, {x = -crosssize.vaule, y = crosssize.vaule}
    }
    
    for i = 1, #points, 2 do
        local p1 = rotate_point(points[i].x, points[i].y)
        local p2 = rotate_point(points[i+1].x, points[i+1].y)
        render.line(p1, p2, current_color, crosthink.vaule)
    end
	else
		engine.execute_client_cmd("crosshair true")
	end
end

function rainbow_color(h, s, v)
    local r, g, b
    
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    
    i = i % 6
    
    if i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    
    return r, g, b
end

local function apply_glow_to_local_player()
    if not glow_enabled.vaule then return end
	if not engine.camera_in_thirdperson() then return end
    
    local local_pawn = entitylist.get_local_player_pawn()
    if local_pawn == nil then return end

    local glow_property = local_pawn.m_Glow
    if glow_property == nil then return end

    glow_hue = (glow_hue + render.frame_time() * 0.5) % 1
    local r, g, b = hsv_to_rgb(glow_hue, 1, 1)

    local glow_color_value = color_t(
        r / 255,
        g / 255,
        b / 255,
        glow_alpha.vaule / 255
    )

    glow_property.m_bGlowing = true
    glow_property.m_glowColorOverride = glow_color_value
    glow_property.m_bEligibleForScreenHighlight = true
end

local function custombg()
	if custom_bg.vaule == true then
		entitylist.get_entities("C_EnvCubemapFog", function(entity)
			if entity == nil then return end
			entity.m_flEndDistance = 10000
			entity.m_flStartDistance = 3000
			entity.m_flFogFalloffExponent = 0.5
			entity.m_flFogHeightWidth = 5000
			entity.m_flFogHeightEnd = 300000
			entity.m_flFogHeightStart = 100
			entity.m_flFogHeightExponent = 2
			entity.m_flLODBias = 10.5
			entity.m_flFogMaxOpacity = 100
		end)
	end
end

local frame_count234 = 0

function hsv_to_rgb234(h, s, v)
    local r, g, b
    
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    
    i = i % 6
    
    if i == 0 then
        r, g, b = v, t, p
    elseif i == 1 then
        r, g, b = q, v, p
    elseif i == 2 then
        r, g, b = p, v, t
    elseif i == 3 then
        r, g, b = p, q, v
    elseif i == 4 then
        r, g, b = t, p, v
    elseif i == 5 then
        r, g, b = v, p, q
    end
    
    return r, g, b
end

local function randomsmoke()
	if randsmoke.vaule == true then
		frame_count234 = frame_count234 + 1
    
		local color_speed = 0.3
    
		entitylist.get_entities("C_SmokeGrenadeProjectile", function(entity)
			if entity == nil then return end
        
			local hue = (frame_count234 * color_speed / 100) % 1
			local r, g, b = hsv_to_rgb234(hue, 1, 1)
        
			entity.m_vSmokeColor = vec3_t(r * 255, g * 255, b * 255)
		end)
	end
end



local function render_center_circle()
    if not enable_circle.vaule then return end
    
    local screen_center = render.screen_size() / 2
    
    render.circle(
        screen_center,
        menu.ragebot_fov * 16.5,
        50,
        color_t(1, 1, 1, 1),
        2
    )
end

local w_pressed = false
local a_pressed = false
local s_pressed = false
local d_pressed = false

local function check_wasd()
    w_pressed = is_key_pressed(0x57)
    a_pressed = is_key_pressed(0x41)
    s_pressed = is_key_pressed(0x53)
    d_pressed = is_key_pressed(0x44)
end

local function adaptive_autostrafe()
    if autostrafe.vaule then 
        check_wasd() 
        
        if w_pressed or a_pressed or s_pressed or d_pressed then
            menu.ragebot_auto_strafer = true
        else
            menu.ragebot_auto_strafer = false
        end
    else
        return
    end
end

local function thirdpercollis()
    if thirdpercoli.vaule then 
		engine.execute_client_cmd("cam_collision 0")
    else
        engine.execute_client_cmd("cam_collision 1") 
    end
end

function base_entity_t:get_index()
    local handle = ffi.cast("uintptr_t", self:get_entity_handle())
    local index = bit.band(handle, 0x7FFF)
    return tonumber(index)
end

function base_entity_t:get_flash_percent()
    local m_flSimTime = self.m_flSimulationTime
    local m_flFlashBangTime = self.m_flFlashBangTime
    local m_flFlashDuration = self.m_flFlashDuration
    local flash_time = m_flFlashBangTime - m_flSimTime
    local flashed_percent = 0

    if m_flFlashDuration > 0 then
        flashed_percent = math.max(0, math.min(1, flash_time / m_flFlashDuration))
    end

    return flashed_percent
end

local keybind_module = {}; do
    local state = {}
    state.toggled = false
    state.last_pressed = false

    local function is_key_down(key)
        return bit.band(ffi.C.GetAsyncKeyState(key), 0x8000) ~= 0
    end

    function keybind_module:active()
        if mode.vaule == 0 then
            return true
        elseif mode.vaule == 1 then
            return is_key_down(keybind.vaule)
        elseif mode.vaule == 2 then
            local pressed = is_key_down(keybind.vaule)
            if pressed and not state.last_pressed then
                state.toggled = not state.toggled
            end
            state.last_pressed = pressed
            return state.toggled
        end

        return false
    end
end

local timers = {}; do
    local queue = {}

    function timers:schedule(delay, func, ...)
        assert(type(delay) == "number" and delay > 0, "Delay must be a positive number")
        assert(type(func) == "function", "Callback must be a function")

        queue[#queue + 1] = {
            delay = delay,
            func = func,
            args = { ... }
        }
    end

    function timers:update()
        local delta_time = render.frame_time()

        for i = #queue, 1, -1 do
            local info = queue[i]
            info.delay = info.delay - delta_time

            if info.delay <= 0 then
                pcall(info.func, unpack(info.args))
                table.remove(queue, i)
            end
        end
    end
end

local trigger = {}; do
    local is_shooting = false

    local function shoot()
        if is_shooting then return end
        is_shooting = true

        timers:schedule(reaction_time.vaule, function()
            engine.execute_client_cmd("+attack")

            timers:schedule(0.1, function()
                is_shooting = false
                engine.execute_client_cmd("-attack")
            end)
        end)
    end

    trigger.active = false

    function trigger:update()
        trigger.active = false

        if not enabled.vaule or not keybind_module:active() then return end

        local local_player_pawn = entitylist.get_local_player_pawn()
        if not local_player_pawn then return end

        if flash_check.vaule then
            local flashed_percent = local_player_pawn:get_flash_percent()

            if flashed_percent > flash_percent.vaule then
                return
            end
        end

        trigger.active = true

        local local_player_team = local_player_pawn.m_iTeamNum
        local crosshair_entity_index = local_player_pawn.m_iIDEntIndex

        if crosshair_entity_index <= 0 then return end

        entitylist.get_entities("C_CSPlayerPawn", function(entity)
            if entity:get_index() ~= crosshair_entity_index then return end

            local entity_team = entity.m_iTeamNum
            if entity_team ~= 2 and entity_team ~= 3 then return end 
            if entity_team == local_player_team then return end    

            shoot()
        end)
    end
end

local indicator = {}; do
    local font = render.setup_font("C:/Windows/Fonts/verdanab.ttf", 16, 0)

    local active_color = color_t(0 / 255, 255 / 255, 0 / 255, 1)   
    local inactive_color = color_t(150 / 255, 150 / 255, 150 / 255, 1) 
    local shadow_color = color_t(0, 0, 0, 1) 

    function indicator:update()
        if not indicators.vaule then return end

        local text = "TB"
        local position = vec2_t(10, 500)
        
        render.text(text, font, position + vec2_t(1, 1), shadow_color)
        
        render.text(text, font, position, trigger.active and active_color or inactive_color)
    end
end

HIT_SOUNDS = {
    [1] = "play sounds/ui/csgo_ui_button_rollover_large", 
    [2] = "play sounds/ui/armsrace_level_up_e",
    [3] = "play sounds/ui/armsrace_become_leader_match",
    [4] = "play sounds/ui/armsrace_kill_01",
    [5] = "play sounds/ui/armsrace_level_down",
    [6] = "play sounds/ui/armsrace_level_up",
    [7] = "play sounds/ui/beep07",
    [8] = "play sounds/ui/beepclear",
    [9] = "play sounds/ui/buttonclick",
    [10] = "play sounds/ui/buttonrollover",
    [11] = "play sounds/ui/counter_beep",
    [12] = "play sounds/buttons/blip1",
    [13] = "play sounds/buttons/blip2",
    [14] = "play sounds/music/kill_01",
    [15] = "play sounds/music/kill_02",
    [16] = "play sounds/music/kill_03",
    [17] = "play sounds/ambient/atmosphere/balloon_pop_01"
}

KILL_SOUNDS = {
    [1] = "play sounds/ui/csgo_ui_button_rollover_large", 
    [2] = "play sounds/ui/armsrace_level_up_e",
    [3] = "play sounds/ui/armsrace_become_leader_match",
    [4] = "play sounds/ui/armsrace_kill_01",
    [5] = "play sounds/ui/armsrace_level_down",
    [6] = "play sounds/ui/armsrace_level_up",
    [7] = "play sounds/ui/beep07",
    [8] = "play sounds/ui/beepclear",
    [9] = "play sounds/ui/buttonclick",
    [10] = "play sounds/ui/buttonrollover",
    [11] = "play sounds/ui/counter_beep",
    [12] = "play sounds/buttons/blip1",
    [13] = "play sounds/buttons/blip2",
    [14] = "play sounds/music/kill_01",
    [15] = "play sounds/music/kill_02",
    [16] = "play sounds/music/kill_03",
    [17] = "play sounds/ambient/atmosphere/balloon_pop_01"
}

local function play_sound(path)
    local SND_FILENAME = 0x00020000
    local SND_ASYNC = 0x0001
    local flags = bit.bor(SND_FILENAME, SND_ASYNC)
    winmm.PlaySoundA(path, nil, flags)
end

KILLS = 0

register_callback("player_hurt", function(event)
    if hit_sound_enabled.vaule and HIT_SOUNDS[hit_sound_type.vaule] then
        local attacker = event:get_pawn("attacker")
        if attacker and attacker == entitylist.get_local_player_pawn() then
            engine.execute_client_cmd(HIT_SOUNDS[hit_sound_type.vaule])
        end
    end
end)

register_callback("player_death", function(event)
    if kill_sound_enabled.vaule and KILL_SOUNDS[kill_sound_type.vaule] then
        local attacker = event:get_pawn("attacker")
        if attacker and attacker == entitylist.get_local_player_pawn() then
            engine.execute_client_cmd(KILL_SOUNDS[kill_sound_type.vaule])
        end
    end
    
    if DOTAkill_sound_enabled.vaule then
        local attacker = event:get_pawn("attacker")
        if attacker and attacker == entitylist.get_local_player_pawn() then
            KILLS = KILLS + 1
            if KILLS == 1 then
                play_sound("nix/scripts/sounds/firstblood.wav")
            elseif KILLS == 2 then
                play_sound("nix/scripts/sounds/doublekill.wav")
            elseif KILLS == 3 then
                play_sound("nix/scripts/sounds/tripplekill.wav")
            elseif KILLS == 4 then
                play_sound("nix/scripts/sounds/megakill.wav")
            elseif KILLS == 5 then
                play_sound("nix/scripts/sounds/monsterkill.wav")
            elseif KILLS == 6 then
                play_sound("nix/scripts/sounds/ultrakill.wav")
            elseif KILLS == 7 then
                play_sound("nix/scripts/sounds/unstoppable.wav")
            elseif KILLS == 8 then
                play_sound("nix/scripts/sounds/godlike.wav")
            elseif KILLS == 9 then
                play_sound("nix/scripts/sounds/dominating.wav")
            elseif KILLS == 10 then
                play_sound("nix/scripts/sounds/holyshit.wav")
            end
        end
    end
    
    if custom_kill_sound_enabled.vaule and custom_sound_files[custom_kill_sounds_combo.value] and custom_sound_files[custom_kill_sounds_combo.value] ~= "No sounds found" then
        local attacker = event:get_pawn("attacker")
        if attacker and attacker == entitylist.get_local_player_pawn() then
            local sound_path = "nix/scripts/PUTYOURSOUNDSHERE/" .. custom_sound_files[custom_kill_sounds_combo.value] .. ".wav"
            play_sound(sound_path)
        end
    end
end)

register_callback("round_start", function()
    KILLS = 0
end)

register_callback("player_hurt", function(event)
       if custom_hit_sound_enabled.vaule and custom_sound_files[custom_hit_sounds_combo.value] and custom_sound_files[custom_hit_sounds_combo.value] ~= "No sounds found" then
        local attacker = event:get_pawn("attacker")
        if attacker and attacker == entitylist.get_local_player_pawn() then
            local sound_path = "nix/scripts/PUTYOURSOUNDSHERE/" .. custom_sound_files[custom_hit_sounds_combo.value] .. ".wav"
            play_sound(sound_path)
        end
    end
end)

local manual_aa = {
    current_yaw = 180,
    STATES = {
        left = 90,
        right = -90,
        default = 180
    },
    held_keys_cache = {},
    
    update = function(self)
        if not manual_aa_enabled.vaule then
            if self.current_yaw ~= self.STATES.default then
                self.current_yaw = self.STATES.default
                menu.ragebot_anti_aim_base_yaw_offset = self.current_yaw
            end
            return
        end
        
        if is_key_pressed(manual_left_bind.vaule) then
            if not self.held_keys_cache.left then
                self.current_yaw = (self.current_yaw == self.STATES.left) and self.STATES.default or self.STATES.left
            end
            self.held_keys_cache.left = true
        else
            self.held_keys_cache.left = false
        end
        
        if is_key_pressed(manual_right_bind.vaule) then
            if not self.held_keys_cache.right then
                self.current_yaw = (self.current_yaw == self.STATES.right) and self.STATES.default or self.STATES.right
            end
            self.held_keys_cache.right = true
        else
            self.held_keys_cache.right = false
        end
        
        menu.ragebot_anti_aim_base_yaw_offset = self.current_yaw
    end,
    
    render_indicator = function(self)
        if not manual_aa_enabled.vaule or not manual_aa_indicators.vaule then return end
        if not entitylist.get_local_player_pawn() then return end

        local screen_center = render.screen_size() / 2
        local active_color = color_t(0, 1, 0, 1)  
        local inactive_color = color_t(0.6, 0.6, 0.6, 1) 
        local shadow_color = color_t(0, 0, 0, 1)    
        local font = font14 
        
        local state_text = "AA: "
        if self.current_yaw == self.STATES.left then
            state_text = state_text .. "LEFT"
        elseif self.current_yaw == self.STATES.right then
            state_text = state_text .. "RIGHT"
        else
            state_text = state_text .. "OFF"
        end
        
        local position = vec2_t(10, 520)
        
        render.text(state_text, font, position + vec2_t(1, 1), shadow_color)
        
        render.text(state_text, font, position, 
            self.current_yaw ~= self.STATES.default and active_color or inactive_color)
    end
}

local glow_particles = {
    max_particles = 50000,
    gravity = 10.1,
    spawn_height = 1000,
    despawn_height = 600,
    spawn_radius = 1000,
    max_fall_speed = 70.2,
    base_size_fg = 0.6,
    base_size_bg = 0.4,
    horizontal_wind_freq = 0.35,
    horizontal_wind_strength = 4,
    spawn_timer = 0,
    current_time = 0,
    particles = {},
    
    create_particle = function(self, player_pos)
        local angle = math.random() * 2 * math.pi
        local radius = math.random() * self.spawn_radius
        local is_fg = math.random() < 0.4
        local pos_x = player_pos.x + radius * math.cos(angle)
        local pos_y = player_pos.y + radius * math.sin(angle)
        local pos_z = player_pos.z + self.spawn_height * math.random()

        return {
            position = { x = pos_x, y = pos_y, z = pos_z },
            previous_position = { x = pos_x, y = pos_y, z = pos_z },
            velocity = {
                x = (math.random() * 2 - 1) * 0.03, 
                y = (math.random() * 2 - 1) * 30.03,
                z = -self.max_fall_speed * (0.6 + math.random() * 70.6),  
            },
            size = (is_fg and self.base_size_fg or self.base_size_bg) * (0.7 + math.random() * 0.5),
            alpha = 0,
            phase = math.random() * math.pi * 2,
            is_foreground = is_fg,
            grounded = false,
            ground_time = 0,
            age = 0,
            life_time = 2 + math.random() * 2
        }
    end,
    
    update_particles = function(self, player_pos, frame_time, frame_count)
        for i = #self.particles, 1, -1 do
            local p = self.particles[i]
            p.age = p.age + frame_time

            if p.age >= p.life_time then
                table.remove(self.particles, i)
            else
                p.previous_position.x = p.position.x
                p.previous_position.y = p.position.y
                p.previous_position.z = p.position.z

                if not p.grounded then
                    p.phase = p.phase + frame_time * 2  
                    local wind_x = math.sin(p.phase + frame_count * self.horizontal_wind_freq) * self.horizontal_wind_strength

                    p.velocity.z = math.max(-self.max_fall_speed, p.velocity.z - self.gravity * frame_time)
                    p.position.x = p.position.x + wind_x * frame_time
                    p.position.y = p.position.y + p.velocity.y * frame_time
                    p.position.z = p.position.z + p.velocity.z * frame_time

                    local ground_z = player_pos.z - self.despawn_height
                    if p.position.z <= ground_z then
                        p.position.z = ground_z
                        p.velocity.z = 0
                        p.grounded = true
                        p.ground_time = 0
                    end
                else
                    p.ground_time = p.ground_time + frame_time
                    p.alpha = math.max(0, p.alpha - frame_time * 0.3) 
                    if p.ground_time > 3 or p.alpha <= 0 then
                        self.particles[i] = self:create_particle(player_pos)
                    end
                end

                if not p.grounded and p.position.z < player_pos.z - self.despawn_height then
                    self.particles[i] = self:create_particle(player_pos)
                end
            end
        end
    end,
    
    render_particles = function(self, player_pos, frame_time)
        for _, p in ipairs(self.particles) do
            local dist = math.sqrt(
                (p.position.x - player_pos.x)^2 +
                (p.position.y - player_pos.y)^2 +
                (p.position.z - player_pos.z)^2
            )

            local max_visible_dist = 4000
            if dist < max_visible_dist then
                local screen_pos = render.world_to_screen(vec3_t(p.position.x, p.position.y, p.position.z))
                local prev_screen = render.world_to_screen(vec3_t(p.previous_position.x, p.previous_position.y, p.previous_position.z))

                if screen_pos and prev_screen then
                    local fade_factor = math.max(0, 1 - (dist / max_visible_dist))
                    if not p.grounded then
                        p.alpha = math.min(p.alpha + frame_time * 1.5, fade_factor * (p.is_foreground and 0.9 or 0.5))
                    end
                    local blur_alpha = p.alpha * 255

                    render.line(prev_screen, screen_pos, color_t(255, 100, 180, blur_alpha))  

                    local size = p.size * fade_factor * 2
                    render.rect_filled(
                        vec2_t(screen_pos.x - size * 2, screen_pos.y - size * 2),
                        vec2_t(screen_pos.x + size * 2, screen_pos.y + size * 2),
                        color_t(1, 0.7, 0.8, p.alpha)
                    )
                end
            end
        end
    end,
    
    update = function(self)
        if not glow_effect_enabled.vaule then
            self.particles = {}
            return
        end

        local player = entitylist.get_local_player_pawn()
        if not player then
            self.particles = {}
            return
        end

        local origin = player:get_abs_origin()
        if not origin then
            self.particles = {}
            return
        end

        local frame_time = render.frame_time()
        local frame_count = render.frame_count()

        self.current_time = self.current_time + frame_time
        if #self.particles < self.max_particles and self.current_time >= self.spawn_timer then
            local particles_to_add = math.min(3, self.max_particles - #self.particles)  
            for i = 1, particles_to_add do
                table.insert(self.particles, self:create_particle(origin))
            end
            self.current_time = 0
        end

        self:update_particles(origin, frame_time, frame_count)
        self:render_particles(origin, frame_time)
    end
}

local exposure_controller = {
    last_exp = 0.65,
    update_needed = true,
    
    init = function(self)
        self.update_exposure_ptr = ffi.cast("uintptr_t", find_pattern("client.dll", "48 89 5C 24 ?? 57 48 83 EC ?? 8B FA 48 8B D9 E8 ?? ?? ?? ?? 84 C0 0F 84 ?? ?? ?? ?? 40 F6 C7"))
        if self.update_exposure_ptr == 0 then
            print("⚠️ Exposure pattern outdated! Effect will not work.")
            return false
        end
        self.update_exposure = ffi.cast("void*(__fastcall*)(uintptr_t, int)", self.update_exposure_ptr)
        return true
    end,
    
    set_exposure = function(self, flValue)
        if not exposure_enabled.vaule then return end
        
        local pLocalPawn = entitylist.get_local_player_pawn()
        if not pLocalPawn then return end
        
        local pCameraServices = pLocalPawn.m_pCameraServices
        if not pCameraServices then return end
        
        local hActivePostProcessingVolume = pCameraServices.m_hActivePostProcessingVolume
        if not hActivePostProcessingVolume then return end
        
        hActivePostProcessingVolume.m_bExposureControl = true
        hActivePostProcessingVolume.m_flExposureFadeSpeedUp = 0
        hActivePostProcessingVolume.m_flExposureFadeSpeedDown = 0
        hActivePostProcessingVolume.m_flMaxExposure = flValue
        hActivePostProcessingVolume.m_flMinExposure = flValue
        
        if self.update_exposure then
            self.update_exposure(ffi.cast("uintptr_t", pCameraServices[0]), 0)
        end
    end,
    
    on_round_start = function(self)
        self.update_needed = true
    end,
    
    on_override_view = function(self)
        if not exposure_enabled.vaule then return end
        
        local new_exp = exposure_value.vaule * 0.01
        
        if self.update_needed or new_exp ~= self.last_exp then
            self.last_exp = new_exp
            self:set_exposure(new_exp)
            self.update_needed = false
        end
    end
}

if not exposure_controller:init() then
    exposure_enabled.vaule = false 
end

register_callback("override_view", function(ctx)
    exposure_controller:on_override_view()
end)

register_callback("round_start", function(ctx)
    exposure_controller:on_round_start()
end)

local aa_switcher_state = false
local last_key_state = false

local function handle_aa_switcher()
    if not aa_switcher_enabled.vaule then return end
    
    local key_pressed = bit.band(ffi.C.GetAsyncKeyState(aa_switcher_bind.vaule), 0x8000) ~= 0
    
    if aa_switcher_mode.vaule == 0 then 
        aa_switcher_state = key_pressed
    else 
        if key_pressed and not last_key_state then
            aa_switcher_state = not aa_switcher_state
        end
    end
    
    last_key_state = key_pressed
    
    if aa_switcher_state then
        menu.ragebot_anti_aim_pitch = 2 
    else
        menu.ragebot_anti_aim_pitch = 1 
    end
end

local function aa_pitchfun()
	--if aa_switcher_enabled.vaule == true then return end
	if aa_pitch.value == 1 then
		engine.execute_client_cmd("cam_idealpitch 0")
		menu.ragebot_anti_aim_pitch = 1
		if aa_switcher_state then
			menu.ragebot_anti_aim_pitch = 2 
		else
			menu.ragebot_anti_aim_pitch = 1 
		end
	end
	if aa_pitch.value == 2 then
		engine.execute_client_cmd("cam_idealpitch 0")
		menu.ragebot_anti_aim_pitch = 2
	end
	if aa_pitch.value == 3 then
		engine.execute_client_cmd("cam_idealpitch 100")
		menu.ragebot_anti_aim_pitch = 0
		if aa_switcher_state then
			menu.ragebot_anti_aim_pitch = 2 
		else
			menu.ragebot_anti_aim_pitch = 0 
		end
	end
end

local function draw_aa_switcher_indicator()
    if not aa_switcher_enabled.vaule or not aa_switcher_indicator.vaule then return end
    if not entitylist.get_local_player_pawn() then return end

    local active_color = color_t(0, 1, 0, 1)  
    local inactive_color = color_t(0.6, 0.6, 0.6, 1)
    local shadow_color = color_t(0, 0, 0, 1)     
    
    local state_text = "FP"
    if aa_switcher_state then
        state_text = state_text .. ""
    else
        state_text = state_text .. ""
    end
    
    local position = vec2_t(10, 539)
    
    render.text(state_text, font14, position + vec2_t(1, 1), shadow_color)
    
    render.text(state_text, font14, position, 
        aa_switcher_state and active_color or inactive_color)
end

local MOUSEEVENTF_MOVE = 0x0001
local SCREEN_CENTER = render.screen_size() / 2

local cooldown_end = 0
local frame_count = 0
local last_target_pos = nil
local AIM_THRESHOLD = 1
local SMOOTH_FACTOR = 1 

local pGameSceneNode = engine.get_netvar_offset("client.dll", "C_BaseEntity", "m_pGameSceneNode")
local modelState = engine.get_netvar_offset("client.dll", "CSkeletonInstance", "m_modelState")
local pBoneMatrix = 0x80
local bone_spacing = 0x20

local BONE_TABLE = {
    [1] = 6,  -- Head
    [2] = 4,  -- Chest
    [3] = 0   -- Body
}

local function move_camera_smooth(dx, dy)
    if SMOOTH_FACTOR > 0 and last_target_pos then
        dx = dx * (1 - SMOOTH_FACTOR) + (last_target_pos.x - SCREEN_CENTER.x) * SMOOTH_FACTOR
        dy = dy * (1 - SMOOTH_FACTOR) + (last_target_pos.y - SCREEN_CENTER.y) * SMOOTH_FACTOR
    end
    
    local move_x = math.floor(dx * (aim_sensitivity.vaule / 50))
    local move_y = math.floor(dy * (aim_sensitivity.vaule / 50))
    
    local steps = math.max(math.floor(math.sqrt(move_x^2 + move_y^2) / 10), 1)
    for i = 1, steps do
        ffi.C.mouse_event(MOUSEEVENTF_MOVE, math.floor(move_x / steps), math.floor(move_y / steps), 0, 0)
    end
end

local function is_in_cooldown()
    return frame_count < cooldown_end
end

local function get_bone_position(entity, bone)
    local node = ffi.cast("uintptr_t*", ffi.cast("uintptr_t", entity[0]) + pGameSceneNode)[0]
    local bm = ffi.cast("uintptr_t*", ffi.cast("uintptr_t", node) + (modelState + pBoneMatrix))[0]
    local p = ffi.cast("struct Vector*", ffi.cast("uintptr_t", bm) + (bone * bone_spacing))[0]
    return vec3_t(p.x, p.y, p.z)
end

local function get_closest_enemy_screen_pos()
    if is_in_cooldown() then return nil end
    
    local local_player = entitylist.get_local_player_pawn()
    if not local_player then return nil end
    
    local local_team = local_player.m_iTeamNum
    local closest_pos = nil
    local min_distance = math.huge
    
    entitylist.get_entities("C_CSPlayerPawn", function(entity)
        if not entity or entity == local_player then return end
        if entity.m_iTeamNum == local_team then return end
        if entity.m_lifeState ~= 0 then return end
        if entity.m_bGunGameImmunity then return end
        
        local bone = BONE_TABLE[aim_bone.value]
        local bone_pos = get_bone_position(entity, bone)
        
            
        local screen_pos = render.world_to_screen(bone_pos)
        
        if screen_pos then
            local distance = math.sqrt(
                (screen_pos.x - SCREEN_CENTER.x)^2 + 
                (screen_pos.y - SCREEN_CENTER.y)^2
            )
            
            if distance < aim_fov.vaule and distance < min_distance then
                min_distance = distance
                closest_pos = screen_pos
            end
        end
    end)
    
    last_target_pos = closest_pos
    return closest_pos
end

register_callback("player_death", function(event)
    local attacker = event:get_pawn("attacker")
    if attacker and attacker == entitylist.get_local_player_pawn() then
        cooldown_end = frame_count + (aim_cooldown.vaule / 16.666)
    end
end)

local settings_path = [[C:\Program Files (x86)\Steam\steamapps\common\Counter-Strike Global Offensive\game\bin\win64\nix\scripts\TriggerBot_Config.cfg]]

local function saveSettings()
    local file = io.open(settings_path, "w")
    if file then
        for tab, settings in pairs(settingList) do
            file:write("[" .. tab .. "]\n")
            for _, setting in ipairs(settings) do
                if setting.name and setting.vaule ~= nil then
                    if setting.type == "boolean" then
                        file:write(setting.name .. "=b:" .. tostring(setting.vaule) .. "\n")
                    elseif setting.type == "int" then
                        file:write(setting.name .. "=i:" .. tostring(setting.vaule) .. "\n")
                    elseif setting.type == "bind" then
                        file:write(setting.name .. "=k:" .. tostring(setting.vaule) .. "\n")
                    elseif setting.type == "combo" then
                        file:write(setting.name .. "=c:" .. tostring(setting.value) .. "\n")
                    end
                end
            end
            file:write("\n")
        end
        file:close()
        print("✅ Config saved.")
    else
        print("❌ Failed to save config.")
    end
end

local function loadSettings()
    local file = io.open(settings_path, "r")
    if not file then
        print("⚠️ Config not found. Creating new one.")
        return
    end

    local currentTab = nil
    for line in file:lines() do
        local tab = line:match("^%[(.+)%]$")
        if tab and settingList[tab] then
            currentTab = tab
        elseif currentTab then
            local name, data = line:match("^(.-)=(.+)$")
            if name and data then
                local typ, val = data:match("^(%a):(.+)$")
                for _, setting in ipairs(settingList[currentTab]) do
                    if setting.name == name then
                        if typ == "b" then
                            setting.vaule = val == "true"
                        elseif typ == "i" or typ == "k" then
                            setting.vaule = tonumber(val)
                        elseif typ == "c" then
                            setting.value = tonumber(val)
                        end
                    end
                end
            end
        end
    end
    file:close()
    print("✅ Config loaded.")
end

local function create_sounds_folder()
    local folder_path = "nix/scripts/PUTYOURSOUNDSHERE"
    
    local handle = io.popen('if exist "'..folder_path..'" (echo 1) else (echo 0)')
    local folder_exists = handle:read("*a")
    handle:close()
    
    if tonumber(folder_exists) == 0 then
        os.execute('mkdir "'..folder_path..'"')
        print("✅ Created sounds folder: "..folder_path)
    else
        print("ℹ️ Sounds folder already exists: "..folder_path)
    end
end

create_sounds_folder()


local autopeek = {
    default_min_damage = 1,
    peek_offset = 1.6,
    peek_limit_meters = 0.5,
    units_per_meter = 1 / 0.0254,
    peek_limit_units = 0.5 * (1 / 0.0254),
    peek_state = "idle",
    peek_dir = 0,
    peek_start_pos = nil,
    KEYEVENTF_KEYUP = 0x0002,
    VK_A = 0x41,
    VK_D = 0x44,
    VK_LSHIFT = 0xA0,
    VK_LCTRL = 0xA2,
    
    init = function(self)
        self.peek_limit_units = self.peek_limit_meters * self.units_per_meter
        self.vecViewOffset = engine.get_netvar_offset("client.dll", "C_BaseModelEntity", "m_vecViewOffset") or 0
        self.pGameSceneNode = engine.get_netvar_offset("client.dll", "C_BaseEntity", "m_pGameSceneNode") or 0
        self.modelState = engine.get_netvar_offset("client.dll", "CSkeletonInstance", "m_modelState") or 0
        self.pBoneMatrix = 0x80
        self.bone_spacing = 0x20
        self.bones = {6, 4, 0}
    end,
    
    press_key = function(self, vk)
        ffi.C.keybd_event(vk, 0, 0, 0)
    end,
    
    release_key = function(self, vk)
        ffi.C.keybd_event(vk, 0, self.KEYEVENTF_KEYUP, 0)
    end,
    
    vec_sub = function(self, a, b) 
        return vec3_t(a.x-b.x, a.y-b.y, a.z-b.z) 
    end,
    
    vec_length = function(self, v) 
        return math.sqrt(v.x*v.x + v.y*v.y + v.z*v.z) 
    end,
    
    is_key_held = function(self, k) 
        return bit.band(ffi.C.GetKeyState(k), 0x8000) ~= 0 
    end,
    
    get_eye_position = function(self, entity, stand)
        if not entity or not entity[0] then return vec3_t(0,0,0) end
        local abs = entity:get_abs_origin()
        local vo = ffi.cast("struct Vector*", ffi.cast("uintptr_t", entity[0]) + self.vecViewOffset)[0]
        local pos = vec3_t(abs.x+vo.x, abs.y+vo.y, abs.z+vo.z)
        if stand and entity.m_pMovementServices then 
            pos.z = pos.z - (entity.m_pMovementServices.m_flDuckOffset or 0)
        end
        return pos
    end,
    
    get_bone_pos = function(self, entity, bone)
        if not entity or not entity[0] then return vec3_t(0,0,0) end
        local node = ffi.cast("uintptr_t*", ffi.cast("uintptr_t", entity[0]) + self.pGameSceneNode)[0]
        if node == nil then return vec3_t(0,0,0) end
        local bm = ffi.cast("uintptr_t*", ffi.cast("uintptr_t", node) + (self.modelState + self.pBoneMatrix))[0]
        if bm == nil then return vec3_t(0,0,0) end
        local p = ffi.cast("struct Vector*", ffi.cast("uintptr_t", bm) + (bone * self.bone_spacing))[0]
        return vec3_t(p.x, p.y, p.z)
    end,
    
    render_point = function(self, pos, highlight)
        local sp = render.world_to_screen(pos)
        if not sp then return end
        render.circle_fade(sp, 4,
            color_t(1, highlight and 0 or 1, highlight and 0 or 1, 0.8),
            color_t(1, highlight and 0 or 1, highlight and 0 or 1, 0))
    end,
    
    is_alive = function(self, entity)
        return entity and entity.m_lifeState and entity.m_lifeState == 0 and entity.m_iHealth and entity.m_iHealth > 0
    end,
    
    is_dormant = function(self, entity)
        return entity and entity.m_bDormant and entity.m_bDormant == true
    end,
    
    is_on_ground = function(self, entity)
        return entity and entity.m_fFlags and bit.band(entity.m_fFlags, 1) == 1
    end,
    
    is_teammate = function(self, a, b)
        if not a or not b then return false end
        if not a.m_iTeamNum or not b.m_iTeamNum then return false end
        return not cvars.mp_teammates_are_enemies:get_bool() and a.m_iTeamNum == b.m_iTeamNum
    end,
    
    update = function(self)
        if not autopeek_enabled.vaule then
            if self.peek_state ~= "idle" then
                if self.peek_dir == -1 then 
                    self:release_key(self.VK_D) 
                else 
                    self:release_key(self.VK_A) 
                end
                self:release_key(self.VK_LSHIFT)
                self.peek_state = "idle"
                self.peek_start_pos = nil
            end
            return
        end

        local ply = entitylist.get_local_player_pawn()
        local ctrl = entitylist.get_local_player_controller()
        if not ply or not ctrl or not self:is_alive(ply) or not self:is_on_ground(ply) then
            if self.peek_state ~= "idle" then
                if self.peek_dir == -1 then 
                    self:release_key(self.VK_D) 
                else 
                    self:release_key(self.VK_A) 
                end
                self:release_key(self.VK_LSHIFT)
                self.peek_state = "idle"
                self.peek_start_pos = nil
            end
            return
        end

        local wep = ply.m_pWeaponServices and ply.m_pWeaponServices.m_hActiveWeapon
        if wep and (wep.m_bInReload or (wep.m_nNextPrimaryAttackTick and ctrl.m_nTickBase and ctrl.m_nTickBase < wep.m_nNextPrimaryAttackTick)) then
            if self.peek_state ~= "idle" then
                if self.peek_dir == -1 then 
                    self:release_key(self.VK_D) 
                else 
                    self:release_key(self.VK_A) 
                end
                self:release_key(self.VK_LSHIFT)
                self.peek_state = "idle"
                self.peek_start_pos = nil
            end
            return
        end

        local view_angles = angle_t(0,0,0)
        local eye_pos = self:get_eye_position(ply, true)
        local _, rvec = math.angle_vectors(view_angles)
        local left_org = eye_pos - rvec * self.peek_offset
        local right_org = eye_pos + rvec * self.peek_offset

        if self.peek_state == "peeking" and self.peek_start_pos then
            if self:vec_length(self:vec_sub(ply:get_abs_origin(), self.peek_start_pos)) >= self.peek_limit_units then
                if self.peek_dir == -1 then 
                    self:release_key(self.VK_D) 
                else 
                    self:release_key(self.VK_A) 
                end
                self:release_key(self.VK_LSHIFT)
                self.peek_state = "idle"
                self.peek_start_pos = nil
                return
            end
        end

        local candidates = {}
        entitylist.get_entities("C_CSPlayerPawn", function(ent)
            if not ent or ent == ply or self:is_dormant(ent) or not self:is_alive(ent) or self:is_teammate(ply, ent) then return end
            if not ent.m_bTakesDamage then return end
            local target_eye_pos = self:get_eye_position(ent, true)
            local fov = math.calc_fov(view_angles, math.calc_angle(eye_pos, target_eye_pos))
            table.insert(candidates, {ent = ent, fov = fov})
        end)
        table.sort(candidates, function(a,b) return a.fov < b.fov end)

        local left_ok, right_ok = false, false
        for i = 1, math.min(1, #candidates) do
            local t = candidates[i].ent
            local need = math.min(self.default_min_damage, t.m_iHealth or 100)
            for _, b in ipairs(self.bones) do
                local p = self:get_bone_pos(t, b)
                if b == 6 then p.z = p.z + 4 end
                local hl = engine.trace_bullet(ply, left_org, p)
                local hr = engine.trace_bullet(ply, right_org, p)
                if autopeek_visualize.vaule then 
                    self:render_point(p, (hl and hl >= need) or (hr and hr >= need)) 
                end
                if hl and hl >= need then left_ok = true end
                if hr and hr >= need then right_ok = true end
            end
        end

        local key = self:is_key_held(autopeek_bind.vaule)
        if self.peek_state == "idle" then
            if key and (left_ok or right_ok) then
                self.peek_state = "peeking"
                self.peek_dir = left_ok and -1 or 1
                self.peek_start_pos = ply:get_abs_origin()
                if self.peek_dir == -1 then 
                    self:release_key(self.VK_A)
                    self:press_key(self.VK_D)
                else 
                    self:release_key(self.VK_D)
                    self:press_key(self.VK_A)
                end
                self:press_key(self.VK_LSHIFT)
            end
        else
            if not key or not (left_ok or right_ok) then
                if self.peek_dir == -1 then 
                    self:release_key(self.VK_D)
                else 
                    self:release_key(self.VK_A)
                end
                self:release_key(self.VK_LSHIFT)
                self.peek_state = "idle"
                self.peek_start_pos = nil
            end
        end
    end,
    
    unload = function(self)
        self:release_key(self.VK_LCTRL)
        self:release_key(self.VK_A)
        self:release_key(self.VK_D)
        self:release_key(self.VK_LSHIFT)
    end
}

autopeek:init()



local ffi = require("ffi")
local bit = require("bit")

ffi.cdef[[
    typedef struct {
        long x;
        long y;
    } POINT;

    int GetCursorPos(POINT* lpPoint);
    int ScreenToClient(void* hWnd, POINT* lpPoint);
    short GetAsyncKeyState(int vKey);
    void* GetForegroundWindow();

    static const int VK_LBUTTON = 0x01;
    static const int VK_RBUTTON = 0x02;
    static const int VK_MBUTTON = 0x04;
    static const int VK_INSERT  = 0x2D;
]]

local user32 = ffi.load("user32")
local keys = {}

local function is_key_pressed(vk_key)
    return bit.band(user32.GetAsyncKeyState(vk_key), 0x8000) ~= 0
end

local function is_key_clicked(vk_key)
    local pressed = is_key_pressed(vk_key)
    if pressed and not keys[vk_key] then
        keys[vk_key] = true
        return true
    elseif not pressed then
        keys[vk_key] = false
    end
    return false
end

local function get_mouse_pos()
    local point = ffi.new("POINT")
    user32.GetCursorPos(point)
    local hwnd = user32.GetForegroundWindow()
    user32.ScreenToClient(hwnd, point)
    return vec2_t(point.x, point.y)
end

local full_height = 21

local animation_start_time = nil

local frame_count = 0
local anim_end = 0

local function lerp(start, end_, t)
    return start + (end_ - start) * t
end

local function reset_animation()
if WATERMARK_enabled.vaule == true then
    animation_start_time = nil
    frame_count = 0
end
end

local function get_animation_progress()
if WATERMARK_enabled.vaule == true then
    if not animation_start_time then
        animation_start_time = frame_count
        return 0
    end
    local elapsed_frames = frame_count - animation_start_time
    local elapsed_seconds = elapsed_frames / 64
    local progress = elapsed_seconds / 0.5
    return math.min(progress, 1.0)
end
end

local function get_current_start_gap()
if WATERMARK_enabled.vaule == true then
    local progress = get_animation_progress()
    return lerp(10, 4, progress)
end
end

local function get_current_gap()
if WATERMARK_enabled.vaule == true then
    local progress = get_animation_progress()
    return lerp(15, 10, progress)
end
end

local function get_current_round()
if WATERMARK_enabled.vaule == true then
	anim_end = 1
    local progress = get_animation_progress()
    return lerp(0, 7, progress)
	--anim_end = 1
end
end

local ascent = color_t(34 / 255.0, 135 / 255.0, 137 / 255.0, 1.0)
local background = color_t(34 / 255.0, 34 / 255.0, 34 / 255.0, 1.0)
local white = color_t(1.0, 1.0, 1.0, 1.0)

local font = render.setup_font("C:/Windows/Fonts/verdana.ttf", 32, 0)
function rect_q2(x, y, width, height, color, rounding)
    render.rect_filled(vec2_t(x, y), vec2_t(x + width, y + height), color, rounding)
end

function width_text(text, size)
    return render.calc_text_size(text, font, size).x
end

function text_2c(text1, text2, x, y, color1, color2, size)
    render.text(text1, font, vec2_t(x, y), color1, size)
    local offset = width_text(text1, size)
    render.text(text2, font, vec2_t(x + offset, y), color2, size)
end

function get_ping()
    local local_controller = entitylist.get_local_player_controller()
    local schema_offset = engine.get_netvar_offset('client.dll', 'CCSPlayerController', 'm_iPing')

    if local_controller ~= nil then
        return ffi.cast('int*', local_controller[schema_offset])[0]
    else
        return 0
    end
end

local offset_x = 10
local offset_y = 10
local full_width = 0

local function MouseInRect(x, y, w, h)
    local mouse = get_mouse_pos()
    return mouse.x >= x and mouse.x <= x + w and mouse.y >= y and mouse.y <= y + h
end

local change = {}
local dx = 0
local dy = 0

function do_drag()
    local Mouse = get_mouse_pos()
    local M1Clicked = is_key_clicked(ffi.C.VK_LBUTTON)
    local M1Pressed = is_key_pressed(ffi.C.VK_LBUTTON)
    local interacting = false

    if M1Clicked and MouseInRect(offset_x, offset_y, full_width, full_height) and not interacting then
        change = {"startpos", 0}
        dx, dy = Mouse.x - offset_x, Mouse.y - offset_y
    end

    if change[1] == "startpos" and not interacting then
        if not M1Pressed then change = {} end
        offset_x, offset_y = Mouse.x - dx, Mouse.y - dy
    end
end

local function reset_animation()
if WATERMARK_enabled.vaule == true then
    animation_start_time = nil
    frame_count = 0
end
end


function renderwater()
if WATERMARK_enabled.vaule == true then
    frame_count = frame_count + 1
    
    do_drag()

    local current_start_gap = get_current_start_gap()
    local current_gap = get_current_gap()
    local current_round = get_current_round()

    local ping = get_ping()
    local user = {
        title = '',
        subtitle = get_user_name()
    }
    local delay = {
        title = '',
        subtitle = tostring(ping) .. ' ms'
    }
    local time = {
        title = '',
        subtitle = os.date('%H:%M')
    }
    local texts = {
        user,
        delay,
        time
    }

    local x = offset_x + current_start_gap + current_gap
    full_width = (current_start_gap * 2) + width_text('HIVRIWARE', 18) + current_gap * 2
    for _, text in ipairs(texts) do
        full_width = full_width + (current_gap * 2) + width_text(text["title"], 14) + width_text(text["subtitle"], 14)
    end

    rect_q2(offset_x, offset_y, full_width, full_height, ascent, current_round)
    rect_q2(offset_x + 4, offset_y, full_width - 8, full_height, background, current_round)

    text_2c('HIVRIWARE', '.lua', x, offset_y + 3, ascent, white, 14)

    local text_x = x + width_text('HIVRIWARE', 18) + current_gap
    for _, text in ipairs(texts) do
        render.circle_filled(vec2_t(text_x, offset_y + 11), 3, 0, ascent)
        text_2c(text["title"], text["subtitle"], text_x + current_gap, offset_y + 3, white, ascent, 14)

        text_x = text_x + (current_gap * 2) + width_text(text["title"], 14) + width_text(text["subtitle"], 14)
    end
end
end

local jump_circles = {}
local was_jumping = false

local function get_current_time()
    return os.clock() * 1000 
end

local function render_jump_circles()
    if not jump_circle_enabled.vaule then return end
    
    local current_time = get_current_time()
    local player = entitylist.get_local_player_pawn()
    
    for i = #jump_circles, 1, -1 do
        if current_time - jump_circles[i].time > 3000 then
            table.remove(jump_circles, i)
        end
    end
    
    if player ~= nil and player.m_lifeState == 0 then
        local is_jumping = player.m_fFlags ~= nil and bit.band(player.m_fFlags, 1) == 0
        
        if is_jumping and not was_jumping then
            table.insert(jump_circles, {
                position = vec3_t(
                    player:get_abs_origin().x,
                    player:get_abs_origin().y,
                    player:get_abs_origin().z
                ),
                time = current_time
            })
        end
        
        was_jumping = is_jumping
        
        for _, circle in ipairs(jump_circles) do
            local time_left = 1000 - (current_time - circle.time)
            local alpha = math.min(1.0, time_left / 1000)
			local time_passed = 1000 - time_left
			local radius_progress = time_passed / 3000
			local radi1 = 7 + (30 - 1) * radius_progress
			local tink1 = 7 + (30 - 1) * radius_progress
			local tink2 = math.min(7.0, time_left / 100 )
			local radi2 = math.min(7.0, time_left / 100 ) 
				if jump_circle_type.value == 1 then
					render.circle_3d(
						circle.position, 
						radi1, 
						color_t(1.0, 1, 1, alpha), 
						tink, 
						vec3_t(0,0,0)
					)
				end
				if jump_circle_type.value == 2 then
					render.circle_3d(
						circle.position, 
						radi2, 
						color_t(1.0, 1, 1, alpha),
						tink2, 
						vec3_t(0,0,0)
					)
				end
				if jump_circle_type.value == 3 then
					render.circle_3d(
						circle.position, 
						radi2, 
						color_t(1.0, 1, 1, alpha),
						3, 
						vec3_t(0,0,0)
					)
				end
				if jump_circle_type.value == 4 then
					render.circle_3d(
						circle.position, 
						radi1, 
						color_t(1.0, 1, 1, alpha),
						3, 
						vec3_t(0,0,0)
					)
				end
        end
    else
        was_jumping = false
    end
end

local fnOnOverrideView = function(pViewSetup)
	if fovcam_enabled.vaule == true then 
		if fovcamfisrt_enabled.vaule == false then 
		pViewSetup.fov = fovcam_value.vaule;
		else
			if engine.camera_in_thirdperson() == true then
				pViewSetup.fov = 90;
			else
				pViewSetup.fov = fovcam_value.vaule;
			end
		end
	else
		pViewSetup.fov = 90;
	end
end;


register_callback("override_view", fnOnOverrideView);

register_callback("paint", function()
    renderGui()
    timers:update()
    trigger:update()
    indicator:update()
    render_center_circle()
    chicken_esp()
    adaptive_autostrafe()
    manual_aa:update()
    manual_aa:render_indicator()
    glow_particles:update()
    apply_glow_to_local_player()
    handle_aa_switcher()
    draw_aa_switcher_indicator()
    autopeek:update()
    renderwater()
    render_jump_circles()
	thirdpercollis()
	aa_pitchfun()
	customcross()
	custombg()
	randomsmoke()
	
	if frame_count >= 10 and anim_end == 1 and WATERMARK_enabled.vaule == false then
		frame_count = 0
		animation_start_time = nil
	end
	
    frame_count = frame_count + 1
    
    if aim_visualize.vaule and aim_enabled.vaule then
        render.circle(SCREEN_CENTER, aim_fov.vaule, 60, color_t(255, 255, 255, 150), 2)
    end
    
    if aim_enabled.vaule and ffi.C.GetAsyncKeyState(aim_key.vaule) ~= 0 and not is_in_cooldown() then
        local target_pos = get_closest_enemy_screen_pos()
        if target_pos then
            local dx = target_pos.x - SCREEN_CENTER.x
            local dy = target_pos.y - SCREEN_CENTER.y
            
            local distance = math.sqrt(dx^2 + dy^2)
            if distance > AIM_THRESHOLD then
                move_camera_smooth(dx, dy)
            end
        end
    end
	engine.execute_client_cmd("cam_idealdist " .. thirdperdist.vaule)
end)

loadSettings()
register_callback("unload", function()
    saveSettings()
    autopeek:unload()
	engine.execute_client_cmd("cam_idealpitch 0")
end)
