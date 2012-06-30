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
	local localToHistorical = {};
	local historicalToLocal = {};
	local ticksPerYear = 403200; --403200 ticks in a year
	
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
			age[unit] = unit.relations.birth_year*ticksPerYear + unit.relations.birth_time;
			count = count+1;
			idToLocalUnit[unit.id] = unit;
			
			if ( unit.hist_figure_id ~= -1 ) then
				local historical_me = idToHistoricalUnit[unit.hist_figure_id];
				localToHistorical[unit] = historical_me;
				historicalToLocal[historical_me] = unit;
			end
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
	local nameHistogram = {};
	local aliveNameHistogram = {};
	local nameFounder = {};
	local nameLeader = {};
	local mostRecentName = -1;
	function handleNewName(dwarf)
		function newNameHelper(name)
			if ( name == -1 ) then
				do return end;
			end
			
  			local old = nameAge[name];
  			if ( old == nil ) then
  				nameAge[name] = age[dwarf];
				nameFounder[name] = dwarf;
				--[[print(string.format("Family founder of %-15s: %s",
					df.global.world.raws.language.translations[0].words[name].value,
					dfhack.TranslateName(dwarf.name)));]]
				mostRecentName = name;
  			else
  				if ( age[dwarf] < old ) then
  					nameAge[name] = age[dwarf];
  				end
  			end
  			
			allNames[name] = 1;
			
			old = nameHistogram[name];
			if ( old == nil ) then
				nameHistogram[name] = 1;
			else
				nameHistogram[name] = old+1;
			end
			
			local alive=false;
			local isLocal;
  			if ( isHistorical(dwarf) ) then
  				if ( dwarf.died_year == -1 ) then
					alive = true;
  				end
				if ( historicalToLocal[dwarf] ~= nil ) then
					isLocal = true;
				else
					isLocal = false;
				end
  			else
				isLocal = true;
  				if ( not dwarf.flags1.dead ) then
					alive = true;
  				end
  			end
			
			if ( alive and isLocal ) then
  				aliveNames[name] = 1;
				old = aliveNameHistogram[name];
				if ( old == nil ) then
					aliveNameHistogram[name] = 1;
					nameLeader[name] = dwarf;
				else
					aliveNameHistogram[name] = old+1;
				end
			end
		end
		for i=0,1 do
			local name = dwarf.name.words[i];
			newNameHelper(name);
		end
	end
	
	function resolveConflict(dwarf)
		local max = getMax(df.global.world.raws.language.words);
		local first = math.random(max)-1;
		local guess = first;
		while (true) do
			--print("    " .. dwarf.name.words[1]);
			if ( nameAge[guess] == nil ) then
				dwarf.name.words[1] = guess;
				break;
			end
			guess = (guess+1)%max;
			if ( guess >= max ) then
				dfhack.error("guess >= max! " .. guess .. ", " .. max);
			end
			if ( guess == first ) then
				dwarf.name.words[1] = guess;
				--dwarf.name.words[1] = mostRecentName;
				--if ( dwarf.name.words[1] == dwarf.name.words[0] ) then
				--	dwarf.name.words[0] = mostRecentName;
				--end
				--TODO: duplicate full names-----------------------------------------------------
				--do return end;-------------------------------------------------------------------------------
				break;
			end
			--print("        " .. nameAge[dwarf.name.words[1]]);
		end
		detectAndResolveConflicts(dwarf);
	end
	
	function detectAndResolveConflicts(dwarf)
		local name = dfhack.TranslateName(dwarf.name);
		if ( allNames[name] ~= nil ) then
			--print("name duplicate: " .. name );
			resolveConflict(dwarf);
			--print("    new name: " .. dfhack.TranslateName(dwarf.name));
			--handleNewName(dwarf);
			do return end;
		end
		
		if ( dwarf.name.words[0] == dwarf.name.words[1] ) then
			--print("same first and last: " .. dwarf.id);
			--print("    1: " .. dwarf.name.words[0]);
			--print("    2: " .. dwarf.name.words[1]);
			resolveConflict(dwarf);
			--handleNewName(dwarf);
			do return end;
		end
		
		--handleNewName(dwarf);
		--sortName(dwarf); --just in case
	end
	
	function sortName(dwarf)
		local name0 = dwarf.name.words[0];
		local name1 = dwarf.name.words[1];
		
		if ( name0 == -1 or name1 == -1 ) then
			do return end;
		end
		
		local age0 = nameAge[name0];
		local age1 = nameAge[name1];
		
		if ( age1 ~= nil and (age0 == nil or age1 < age0) ) then
			dwarf.name.words[0] = name1;
			dwarf.name.words[1] = name0;
		elseif ( age1 == age0 ) then
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
		
		--sortName(dwarf);
		
		if ( not isHistorical(dwarf) ) then
			local hist_me = idToHistoricalUnit[dwarf.hist_figure_id];
			if ( hist_me ~= nil ) then
				dwarf.name.words[0] = hist_me.name.words[0];
				dwarf.name.words[1] = hist_me.name.words[1];
				do return end;
			end
		end
		
		--print("id = " .. dwarf.id);
		
		local parent1 = getParent(dwarf, "mother");
		local parent2 = getParent(dwarf, "father");
		
		local oldName0 = dwarf.name.words[0];
		local oldName1 = dwarf.name.words[1];
		local oldNameString = dfhack.TranslateName(dwarf.name);
		
		if ( oldName0 == -1 or oldName1 == -1 ) then
			handleNewName(dwarf);
			do return end; -- don't mess with weird shit
		end
		
		if ( parent1 == nil and parent2 == nil ) then
			--print("Generating unique last name for " .. dfhack.TranslateName(dwarf.name));
			local seed;
			if ( isHistorical(dwarf) ) then
				seed = dwarf.id;
			else
				local hist_me = idToHistoricalUnit[dwarf.hist_figure_id];
				if ( hist_me ~= nil ) then
					seed = hist_me.id;
				else
					seed = dwarf.id;
				end
			end
			math.randomseed(seed);
			--print("seed = " .. seed);
			local max = getMax(df.global.world.raws.language.words);
			--print("max = " .. max);
			local first = math.random(max)-1;
			local guess = first;
			while(true) do
				if ( nameAge[guess] == nil ) then
					dwarf.name.words[0] = guess;
					break;
				end
				guess = (guess+1)%max;
				if ( guess == first ) then
					dwarf.name.words[0] = guess;
					--dwarf.name.words[0] = mostRecentName;
					--dwarf.name.words[1] = mostRecentName; -- gonna happen anyway
					break;
				end;
			end
			
			first = math.random(max)-1;
			if ( first == dwarf.name.words[0] ) then
				first = (first+1)%max;
			end
			guess = first;
			local lastNonduplicate;
			while(true) do
				if ( guess ~= dwarf.name.words[0] and nameAge[guess] == nil ) then
					dwarf.name.words[1] = guess;
					break;
				end
				local fullName = dfhack.TranslateName(dwarf.name);
				if ( allNames[fullName] == nil ) then
					lastNonduplicate = guess;
				end
				guess = (guess+1)%max;
				if ( guess == first ) then
					dwarf.name.words[1] = lastNonduplicate;
					--dwarf.name.words[1] = mostRecentName;
					break;
				end;
			end
			
			local newNameString = dfhack.TranslateName(dwarf.name);
			if ( oldNameString ~= newNameString ) then
				print("No parents: giving new unique last names (if possible):");
				print("    old name = " .. oldNameString);
				print("    new name = " .. newNameString);
				print();
			end
			--print("    " .. dfhack.TranslateName(dwarf.name));
			handleNewName(dwarf);
			do return end;
		end
		
		if ( parent1 == nil or parent2 == nil ) then
			handleNewName(dwarf);
			do return end;
		end
		
		--not sure this is necessary
		--[[if ( age[parent2] < age[parent1] ) then
			local temp = parent1;
			parent1 = parent2;
			parent2 = temp;
		end--]]
		
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
		local seed;
		if ( isHistorical(dwarf) ) then
			seed = dwarf.id;
		else
			local hist_me = idToHistoricalUnit[dwarf.hist_figure_id];
			if ( hist_me ~= nil ) then
				seed = hist_me.id;
			else
				seed = dwarf.id;
			end
		end
		--print("seed = " .. seed);
		math.randomseed(seed);
		
		detectAndResolveConflicts(dwarf);
		--only handleNewName when their name is finalized!
		handleNewName(dwarf);
		
		local newNameString = dfhack.TranslateName(dwarf.name);
		
		if ( oldNameString ~= newNameString ) then
			--print("seed = " .. seed);
			--print("child index = " .. childIndex);
			print("old name = " .. oldNameString);
			print("new name = " .. newNameString);
			--print("parent1 = " .. parent1.id);
			--print("    " .. dfhack.TranslateName(parent1.name));
			--print("parent2 = " .. parent2.id);
			--print("    " .. dfhack.TranslateName(parent2.name));
			--print("nameAge[" .. nameTable[1] .. "] = " .. nameAge[nameTable[1]]);
			--print("nameAge[" .. nameTable[2] .. "] = " .. nameAge[nameTable[2]]);
			--print("nameAge[" .. nameTable[3] .. "] = " .. nameAge[nameTable[3]]);
			--print("nameAge[" .. nameTable[4] .. "] = " .. nameAge[nameTable[4]]);
			print();
			--dfhack.error("bob!");
		end
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
				local temp = 
				print(string.format("    family %-15s: uses = %-4s, localAliveUses = %4s",
					str,
					tostring(nameHistogram[name]),
					tostring(aliveNameHistogram[name])));
				
				print(string.format("        founded in %-4.2f by %s",
					nameAge[name]/ticksPerYear,
					dfhack.TranslateName(nameFounder[name].name)));
				print(string.format("        locally led by %s",
					dfhack.TranslateName(nameLeader[name].name)));
				print();
			end
		end
	end
	printNameAges();
end

--computeHeritage();
dfhack.with_suspend(computeHeritage);
