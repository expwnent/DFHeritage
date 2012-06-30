function isHistorical(unit)
	local type = tostring(unit._type);
	--print(type);
	if ( string.find(type, "historical_figure") ~= nil ) then
		do return true end;
	end
	
	if ( string.find(type, "unit") ~= nil ) then
		do return false end;
	end
	
	dfhack.error("unit is not of a valid type: " .. unit);
	do return nil end;
end

function getRelation(figure, typeString)
	for index,link in pairs(figure.histfig_links) do
		local type = tostring(link._type);
		if ( string.find(type, typeString) ~= nil ) then
			do return link.anon_1 end;
		end
	end
	do return nil end;
end

function merge(list, lessThan, lo, mid, hi)
	local temp = {};
	local index_L = lo;
	local index_R = mid;
	local index_temp = 0;
	while(true) do
		if ( index_L >= mid ) then
			if ( index_R < hi ) then
				temp[index_temp] = list[index_R];
				index_temp = index_temp+1;
				index_R = index_R+1;
			else
				break;
			end
		else
			if ( index_R < hi ) then
				if ( lessThan(index_R, index_L) ) then
					temp[index_temp] = list[index_R];
					index_temp = index_temp+1;
					index_R = index_R+1;
				else
					temp[index_temp] = list[index_L];
					index_temp = index_temp+1;
					index_L = index_L + 1;
				end
			else
				temp[index_temp] = list[index_L];
				index_temp = index_temp+1;
				index_L = index_L + 1;
			end
		end
	end
	
	for i=lo,hi-1 do
		list[i] = temp[i-lo];
	end
end

function sort(list, lessThan, lo, hi)
	if ( lo == hi or lo > hi or lo+1 == hi ) then
		do return end;
	end
	
	local mid = math.floor((lo+hi)/2);
	sort(list, lessThan, lo, mid);
	sort(list, lessThan, mid, hi);
	
	merge(list, lessThan, lo, mid, hi);
end
	
function getMax(list)
	local result = 0;
	for key,value in pairs(list) do
		if ( key >= result ) then
			result = key+1;
		end
	end
	return result;
end

function computeHeritage()
	local dwarfRace = df.global.ui.race_id;
	local allUnits = {};
	local age = {};
	local count=0;
	local idToHistoricalUnit = {};
	local idToLocalUnit = {};
	
	for index,unit in pairs(df.global.world.history.figures) do
		if ( unit.race == dwarfRace ) then
			allUnits[count] = unit;
			age[unit] = unit.born_year*403200 + unit.born_seconds;
			count = count+1;
			idToHistoricalUnit[unit.id] = unit;
		end
	end
	
	for index,unit in pairs(df.global.world.units.all) do
		if ( unit.race == dwarfRace ) then
			allUnits[count] = unit;
			age[unit] = unit.relations.birth_year*403200 + unit.relations.birth_time; --403200 ticks in a year
			count = count+1;
			idToLocalUnit[unit.id] = unit;
		end
	end
	
	--print("Sorting...");
	--sort units
	function lessThan(index1, index2)
		if ( index1 == index2 ) then
			do return false end;
		end
		local unit1 = allUnits[index1];
		local unit2 = allUnits[index2];
		
		--print(tostring(index1) .. ", " .. tostring(index2));
		--print(tostring(unit1) .. ", " .. tostring(unit2));
		
		if ( isHistorical(unit1) == isHistorical(unit2) ) then
			if ( age[unit2] < age[unit1] ) then
				do return false end;
			end
		else
			if ( isHistorical(unit2) ) then
				do return false end;
			end
		end
		
		return true;
	end
	sort(allUnits, lessThan, 0, count);
	
	--print("Done sorting!");
	
	function getParent(unit, whichParent)
		if ( isHistorical(unit) ) then
			local id = getRelation(unit, whichParent);
			return idToHistoricalUnit[id];
		else
			--try the parent of your historical version if you have one
			if ( unit.hist_figure_id ~= -1 ) then
				local hist_me = idToHistoricalUnit[unit.hist_figure_id];
				local hist_parent = getParent(hist_me, whichParent);
				if ( hist_parent ~= nil ) then
					do return hist_parent end;
				end
			end
			local id;
			if ( whichParent == "mother" ) then
				id = unit.relations.mother_id;
			elseif ( whichParent == "father" ) then
				id = unit.relations.father_id;
			else
				dfhack.error("Invalid relation: " .. whichParent);
			end
			if ( id == -1 ) then
				do return nil end;
			end
			
			local ancestor = idToLocalUnit[id];
			if ( ancestor == nil ) then
				do return nil end;
			end
			
			if ( ancestor.hist_figure_id == -1 or idToHistoricalUnit[ancestor.hist_figure_id] == nil ) then
				do return ancestor end;
			end
			
			do return idToHistoricalUnit[ancestor.hist_figure_id] end;
		end
	end
	
	local childIndexTable = {};
	local allNames = {};
	local nameAge = {};
	
	function computeChildIndexTable()
		--precondition: units are sorted by birth order
		local childTable = {};
		local childCount = {};
		local result = {};
		function helper(unit)
			local mother = getParent(unit, "mother");
			if ( mother == nil ) then
				do return end;
			end
			local children = childTable[mother];
			if ( children == nil ) then
				children = {};
				childCount[mother] = 0;
			end
			
			--if you're historical, you might already be in the list!
			if ( not isHistorical(unit) ) then
				local alternate = idToHistoricalUnit[unit.hist_figure_id];
				if ( alternate == nil ) then
					--no alternate, fall through to base case
				else
					--we do have an alternate: copy his childIndex
					result[unit] = result[alternate];
					do return end;
				end
			end
			
			local count = childCount[mother];
			children[count] = unit;
			childCount[mother] = count+1;
			childTable[mother] = children;
			result[unit] = count;
		end
		for index,unit in pairs(allUnits) do
			helper(unit);
		end
		return result;
	end
	
	childIndexTable = computeChildIndexTable();
	
	local aliveNames = {};
	function handleNewName(dwarf)
		for i=0,1 do
			local name = dwarf.name.words[i];
			local old = nameAge[name];
			if ( old == nil ) then
				nameAge[name] = age[dwarf];
			else
				if ( age[dwarf] < old ) then
					nameAge[name] = age[dwarf];
				end
			end
			if ( isHistorical(dwarf) ) then
				if ( dwarf.died_year == -1 ) then
					--aliveNames[name] = 1;
				end
			else
				if ( not dwarf.flags1.dead ) then
					aliveNames[name] = 1;
				end
			end
		end
	end
	
	for index,unit in pairs(allUnits) do
		handleNewName(unit);
	end
	
	function resolveConflict(dwarf)
		local max = getMax(df.global.world.raws.language.words);
		while (true) do
			dwarf.name.words[1] = math.random(max+1)-1;
			if ( nameAge[dwarf.name.words[1]] == nil ) then
				break;
			end
		end
		detectAndResolveConflicts(dwarf);
	end
	
	function detectAndResolveConflicts(dwarf, requireUnique)
		local name = dfhack.TranslateName(dwarf.name);
		if ( allNames[name] ~= nil ) then
			--print("name duplicate: " .. name );
			resolveConflict(dwarf);
			--print("    new name: " .. dfhack.TranslateName(dwarf.name));
			--handleNewName(dwarf);
			do return end;
		end
		
		if ( dwarf.name.words[0] == dwarf.name.words[1] ) then
			resolveConflict(dwarf);
			--handleNewName(dwarf);
			do return end;
		end
		
		--local max = getMax(df.global.world.raws.language.words);
		if ( requireUnique == true ) then
			dfhack.error("duuuuh?");
			for i=0,1 do
				local nameI = dwarf.name.words[i];
				if ( nameAge[nameI] ~= nil ) then
					if ( i == 0 ) then
						dwarf.name.words[0] = dwarf.name.words[1];
						dwarf.name.words[1] = nameI;
					end
					resolveConflict(dwarf);
					--handleNewName(dwarf);
					do return end;
				end
			end
		end
		handleNewName(dwarf);
		sortName(dwarf);
		
		allNames[name] = 1;
	end
	
	function sortName(dwarf)
		local name0 = dwarf.name.words[0];
		local name1 = dwarf.name.words[1];
		
		if ( name0 == -1 or name1 == -1 ) then
			do return end;
		end
		
		if ( nameAge[name1] < nameAge[name0] ) then
			dwarf.name.words[0] = name1;
			dwarf.name.words[1] = name0;
		elseif ( nameAge[name1] == nameAge[name0] ) then
			local str1 = df.global.world.raws.language.translations[0].words[name0].value;
			local str2 = df.global.world.raws.language.translations[0].words[name1].value;
			if ( str2 < str1 ) then
				dwarf.name.words[0] = name1;
				dwarf.name.words[1] = name0;
			end
		end
	end
	
	helper = function(dwarf)
		if ( dwarf.race ~= dwarfRace ) then
			do return end;
		end
		
		sortName(dwarf);
		
		local parent1 = getParent(dwarf, "mother");
		local parent2 = getParent(dwarf, "father");
		
		local oldName0 = dwarf.name.words[0];
		local oldName1 = dwarf.name.words[1];
		
		if ( oldName0 == -1 or oldName1 == -1 ) then
			do return end; -- don't mess with weird shit
		end
		
		if ( parent1 == nil and parent2 == nil ) then
			--[[print("Generating unique last name for " .. dfhack.TranslateName(dwarf.name));
			if ( isHistorical(dwarf) ) then
				math.randomseed(dwarf.id);
			else
				local hist_me = idToHistoricalUnit[dwarf.hist_figure_id];
				if ( hist_me ~= nil ) then
					math.randomseed(hist_me.id);
				else
					math.randomseed(dwarf.id);
				end
			end
			detectAndResolveConflicts(dwarf, true);
			print("    " .. dfhack.TranslateName(dwarf.name));]]
			do return end;
		end
		
		if ( parent1 == nil or parent2 == nil ) then
			do return end;
		end
		
		if ( not isHistorical(dwarf) ) then
			local hist_me = idToHistoricalUnit[dwarf.hist_figure_id];
			if ( hist_me ~= nil ) then
				dwarf.name.words[0] = hist_me.name.words[0];
				dwarf.name.words[1] = hist_me.name.words[1];
				do return end;
			end
		end
		
		--not sure this is necessary
		if ( age[parent2] < age[parent1] ) then
			local temp = parent1;
			parent1 = parent2;
			parent2 = temp;
		end
		
		local nameTable = {};
		nameTable[1] = parent1.name.words[0];
		nameTable[2] = parent1.name.words[1];
		nameTable[3] = parent2.name.words[0];
		nameTable[4] = parent2.name.words[1];
		
		for i=1,5 do
			for j=2,4 do
				local temp1 = nameTable[j-1];
				local temp2 = nameTable[j  ];
				if ( nameAge[temp2] < nameAge[temp1] ) then
					nameTable[j-1] = temp2;
					nameTable[j  ] = temp1;
				elseif ( nameAge[temp2] == nameAge[temp1] ) then
					--both equal: go by alphabetic?
					local str1 = df.global.world.raws.language.translations[0].words[temp1].value;
					local str2 = df.global.world.raws.language.translations[0].words[temp2].value;
					if ( str2 < str1 ) then
						nameTable[j-1] = temp2;
						nameTable[j  ] = temp1;
					end
				end
			end
		end
		
		local newName0 = -1;
		local newName1 = -1;
		
		local childIndex = childIndexTable[dwarf];
		childIndex = childIndex % 6;
		
		if ( childIndex == 0 ) then
			newName0 = nameTable[1];
			newName1 = nameTable[2];
		elseif ( childIndex == 1 ) then
			newName0 = nameTable[3];
			newName1 = nameTable[4];
		elseif ( childIndex == 2 ) then
			newName0 = nameTable[1];
			newName1 = nameTable[3];
		elseif ( childIndex == 3 ) then
			newName0 = nameTable[2];
			newName1 = nameTable[4];
		elseif ( childIndex == 4 ) then
			newName0 = nameTable[1];
			newName1 = nameTable[4];
		elseif ( childIndex == 5 ) then
			newName0 = nameTable[2];
			newName1 = nameTable[3];
		else
			dfhack.error("Invalid child index: " .. childIndex);
		end
		
		local oldNameString = dfhack.TranslateName(dwarf.name);
		dwarf.name.words[0] = newName0;
		dwarf.name.words[1] = newName1;
		
		--resolve conflicts
		--choose the same new name in the event of a conflict
		if ( isHistorical(dwarf) ) then
			math.randomseed(dwarf.id);
		else
			local hist_me = idToHistoricalUnit[dwarf.hist_figure_id];
			if ( hist_me ~= nil ) then
				math.randomseed(hist_me.id);
			else
				math.randomseed(dwarf.id);
			end
		end
		
		detectAndResolveConflicts(dwarf);
		
		local oldNameString = dfhack.TranslateName(dwarf.name);
	end
	
	for index,dwarf in pairs(allUnits) do
		helper(dwarf);
	end
	
	--print out the age of each name
	function printNameAges()
		local count = 0;
		local newList = {};
		for name,_ in pairs(aliveNames) do
			newList[count] = name;
			count = count+1;
		end
		function ageLessThan(a,b)
			if ( a == b ) then
				do return false end;
			end
			
			local name1 = newList[a];
			local name2 = newList[b];
			if (nameAge[name1] < nameAge[name2]) then
				return true;
			elseif (nameAge[name1] == nameAge[name2]) then
				local str1 = df.global.world.raws.language.translations[0].words[name1].value;
				local str2 = df.global.world.raws.language.translations[0].words[name2].value;
				return str1 < str2;
			end
			return false;
		end
		sort(newList, ageLessThan, 0, count);
		
		print("Names that are present in this fort (oldest names listed first): ");
		for i=0,count-1 do
			local name = newList[i];
			if ( name >= 0 ) then
				local str = df.global.world.raws.language.translations[0].words[name].value;
				print("    "..str);
				print("        " .. nameAge[name]);
			end
		end
	end
	printNameAges();
end

dfhack.with_suspend(computeHeritage);
