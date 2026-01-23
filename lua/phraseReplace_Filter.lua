-- phraseReplace_Filter.lua
-- Copyright (C) 2023 yaoyuan.dou <douyaoyuan@126.com>
--[[
这个过滤器的主要作用是，对于候选项中命中的选项(OR 内容)，用其指定的内容来代替，如果没有指定，则使用 * 替换
由于这个过滤器会改变候选项的内容，所以请将这个过滤器放在其它过滤器的最前端使用

👉把本脚本（包括txt文档和lua文档）放在你的方案的lua路径下
👉你需要在你的方案中添加以下开关
   - name: phraseReplace			# 敏感词输出开关
      reset: 1
      states: [Off, 👙]
👉你需要在你的方案中添加以下开关
    - name: autoMix					# 一个开关，用于决定是否打开自动混淆功能
      states: [Off, mix]
👉你需要在你的方案中引用以下滤镜脚本
  engine/filters:									# 设置以下filter
    - lua_filter@*phraseReplace_Filter
]]
local phraseReplaceModuleEnable, phraseReplaceModule = pcall(require, 'phraseReplaceModule')

local logEnable, log = pcall(require, "runLog")
if logEnable then
	log.writeLog('')
	log.writeLog('log from phraseReplace_Filter.lua')
	log.writeLog('phraseReplaceModuleEnable:'..tostring(phraseReplaceModuleEnable))
end

local phraseReplaceFilter = {}
local lenOfSuiJiZiFu = 0

-- 如果脱敏词中存在符号 ※，则会随机使用suiJiZiFu中的一个符号替换符号※
local suiJiZiFu = {'*','-','¹','₁','²','₂','³','₃','⁴','₄','⁵','₅','⁶','₆','⁷'
					,'₇','⁸','₈','⁹','₉','⁰','₀','ᴬ','ᵃ','ᵄ','ᵅ','ᶛ','ᴭ','ᵆ',
					'⁽','⁾','˜','⁺','⁻','⁼','‸','₊','₋','₌','₍','₎'}

local function getSuiJiZiFu()
    return suiJiZiFu[math.random(1, lenOfSuiJiZiFu)]
end

function phraseReplaceFilter.init(env)
	lenOfSuiJiZiFu = #suiJiZiFu
end

function phraseReplaceFilter.func(input, env)
	--获取选项敏感词替换开关状态
	local on = env.engine.context:get_option("phraseReplace") or false
	local mixFlg = env.engine.context:get_option("autoMix") or false
	
	--一个字典，用于暂存存在于候选词中的敏感词及其替换词
	local keyValDic = {}
	
	local candStart,candEnd
	
	for cand in input:iter() do
		candStart = cand.start
		candEnd = cand._end
		
		local candTxt = cand.text:gsub("%s","") or ""
		local candComment = cand.comment or ""
		
		if mixFlg then -- 做混淆处理
			local mixedStr = ''
			for u8 in string.gmatch(candTxt, "([%z\1-\127\194-\244][\128-\191]*)") do
				mixedStr = mixedStr..u8..getSuiJiZiFu()
			end
			yield(Candidate(cand.type, cand.start, cand._end, mixedStr, candComment))
		else -- 做脱敏处理
			--清空敏感词暂存字典
			keyValDic = {}
			
			--循环遍历每一个敏感词，以检查是否有某个敏感词存在于候选项中
			for k,v in pairs(phraseReplaceModule.dict) do
				if string.find(candTxt,k) then
					keyValDic[k] = v
				end
			end
			
			if next(keyValDic) then
				--如果存在至少一个敏感词，则不论是否进行了脱敏处理，都加上敏感标记 👙
				candComment = '👙'..candComment
				
				if on then
					--逐一替换到候选项中的敏感词
					for k,v in pairs(phraseReplaceModule.dict) do
						if '' == v then
							v = '*'
						end
						-- 处理随机替换需求
						v = string.gsub(v,'※',getSuiJiZiFu())
						-- 替换原候字符
						candTxt = string.gsub(candTxt, k, v)
					end
					yield(Candidate(cand.type, cand.start, cand._end, candTxt, candComment))
					
				else
					--如果没有开启脱敏功能，则抛出原选项
					cand.comment = candComment
					yield(cand)
				end
			else
				--如果不存在敏感词，则抛出原选项
				yield(cand)
			end
		end
	end
end

return phraseReplaceFilter
