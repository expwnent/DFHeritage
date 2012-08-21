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

local doOnce = 0;

function sort(list, lessThan, lo, hi)
	if ( lo == hi or lo > hi or lo+1 == hi ) then
		do return end;
	end
	
	--print("lo="..lo..", hi="..hi);
	
	--[[--see if some of it is already sorted
	local firstUnsorted = 0;
	local previous = list[lo];
	local index = lo+1;
	while(true) do
		index = index+1;
		if ( index >= hi ) then
			break;
		end
		
		if ( lessThan(index, index-1) ) then
			firstUnsorted = index;
			if ( doOnce == 0 ) then
				print(firstUnsorted);
				doOnce = 1;
			end
			break;
		end
	end
	
	if ( firstUnsorted - lo > 10 and firstUnsorted - lo >= (hi-lo)/4 ) then
		local mid = firstUnsorted-1;
		--sort(list, lessThan, lo, mid);
		sort(list, lessThan, mid, hi);
		merge(list, lessThan, lo, mid, hi);
		do return end;
	end]]
	
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

function computeHeritage(nameScheme, outputType, sortOutputBy, doReverseOutputOrder)
	local dwarfRace = df.global.ui.race_id;
	local allUnits = {};
	local age = {};
	local count=0;
	local idToHistoricalUnit = {};
	local idToLocalUnit = {};
	local localToHistorical = {};
	local historicalToLocal = {};
	local ticksPerYear = 403200; --403200 ticks in a year
	
	--compute allUnits, age, count, idToHistoricalUnit
	for index,unit in pairs(df.global.world.history.figures) do
		if ( unit.race == dwarfRace ) then
			allUnits[count] = unit;
			age[unit] = unit.born_year*403200 + unit.born_seconds;
			count = count+1;
			idToHistoricalUnit[unit.id] = unit;
		end
	end
	
	--compute allUnits, age, count, idToLocalUnit, localToHistorical, historicalToLocal
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
	
	print("Sorting...");
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
	
	print("Done sorting!");
	
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
	local localNameHistogram = {};
	local localAliveNameHistogram = {};
	local nameFounder = {};
	local nameLeader = {};
	local localNameLeader = {};
	local localNameFounder = {};
	local outOfNames = false;
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
			
			if ( isLocal ) then
				old = localNameHistogram[name];
				if ( old == nil ) then
					localNameHistogram[name] = 1;
					localNameFounder[name] = dwarf;
				else
					localNameHistogram[name] = old+1;
				end
			end
			
			if ( alive ) then
				old = aliveNameHistogram[name];
				if ( old == nil ) then
					nameLeader[name] = dwarf;
					aliveNameHistogram[name] = 1;
				else
					aliveNameHistogram[name] = old+1;
				end
			end
			
			if ( alive and isLocal ) then
				aliveNames[name] = 1;
				old = localAliveNameHistogram[name];
				if ( old == nil ) then
					localAliveNameHistogram[name] = 1;
					localNameLeader[name] = dwarf;
				else
					localAliveNameHistogram[name] = old+1;
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
			if ( nameAge[guess] == nil ) then
				dwarf.name.words[1] = guess;
				break;
			end
			guess = (guess+1)%max;
			if ( guess >= max ) then
				dfhack.error("guess >= max! " .. guess .. ", " .. max);
			end
			if ( outOfNames or guess == first ) then
				outOfNames = true;
				dwarf.name.words[1] = first;
				--TODO: duplicate full names-----------------------------------------------------
				--do return end;
				break;
			end
		end
		detectAndResolveConflicts(dwarf);
	end
	
	function detectAndResolveConflicts(dwarf)
		local name = dfhack.TranslateName(dwarf.name);
		if ( allNames[name] ~= nil ) then
			resolveConflict(dwarf);
			do return end;
		end
		
		if ( dwarf.name.words[0] == dwarf.name.words[1] ) then
			resolveConflict(dwarf);
			do return end;
		end
		
		if ( dwarf.name.words[1] == -1 ) then
			resolveConflict(dwarf);
			do return end;
		end
		
		if ( dwarf.name.words[0] == -1 ) then
			dwarf.name.words[0] = dwarf.name.words[1];
			dwarf.name.words[1] = -1;
			resolveConflict(dwarf);
			local temp = dwarf.name.words[0];
			dwarf.name.words[0] = dwarf.name.words[1];
			dwarf.name.words[1] = temp;
		end
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
				if ( outOfNames or guess == first ) then
					outOfNames = true;
					dwarf.name.words[0] = first;
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
				if ( outOfNames or guess == first ) then
					outOfNames = true;
					dwarf.name.words[1] = lastNonduplicate;
					--dwarf.name.words[1] = mostRecentName;
					break;
				end;
			end
			
			sortName(dwarf);
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
		
		local nameTable = {};
		nameTable[1] = parent1.name.words[0];
		nameTable[2] = parent1.name.words[1];
		nameTable[3] = parent2.name.words[0];
		nameTable[4] = parent2.name.words[1];
		
		for i=1,5 do
			for j=2,4 do
				local temp1 = nameTable[j-1];
				local temp2 = nameTable[j  ];
				local age1 = nameAge[temp1] or 1000000;
				local age2 = nameAge[temp2] or 1000000;
				if ( age2 < age1 ) then
					nameTable[j-1] = temp2;
					nameTable[j  ] = temp1;
				elseif ( age2 == age1 ) then
					--both equal: go by alphabetic
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
		
		--[[if ( childIndex == 0 ) then
			newName0 = nameTable[1];
			newName1 = nameTable[2];
		elseif ( childIndex == 1 ) then
			newName0 = nameTable[1];
			newName1 = nameTable[3];
		elseif ( childIndex == 2 ) then
			newName0 = nameTable[1];
			newName1 = nameTable[4];
		elseif ( childIndex == 3 ) then
			newName0 = nameTable[2];
			newName1 = nameTable[3];
		elseif ( childIndex == 4 ) then
			newName0 = nameTable[2];
			newName1 = nameTable[4];
		elseif ( childIndex == 5 ) then
			newName0 = nameTable[3];
			newName1 = nameTable[4];
		else
			dfhack.error("Invalid child index: " .. childIndex);
		end--]]
		
		--[[newName0 = nameTable[1];
		newName1 = nameTable[2];
		if ( newName1 == newName0 ) then
			newName1 = nameTable[3];
			if ( newName1 == newName0 ) then
				newName1 = nameTable[4];
			end
		end--]]
		
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
		
		if ( nameScheme == 'motherName' ) then
			if ( parent1 == nil ) then
				parent1 = parent2;
			end
			if ( parent1 == nil ) then
				do return end;
			end
			dwarf.name.words[0] = parent1.name.words[0];
			dwarf.name.words[1] = parent1.name.words[1];
			--do return end;
		elseif ( nameScheme == 'fatherName' ) then
			if ( parent2 == nil ) then
				parent2 = parent1;
			end
			if ( parent2 == nil ) then
				do return end;
			end
			dwarf.name.words[0] = parent2.name.words[0];
			dwarf.name.words[1] = parent2.name.words[1];
		elseif ( nameScheme == 'eldestParent' ) then
			local olderParent;
			if ( parent1 == nil and parent2 ~= nil ) then
				olderParent = parent2;
			elseif ( parent2 == nil and parent1 ~= nil ) then
				olderParent = parent1;
			else
				if ( parent1 == nil or parent2 == nil ) then
					dfhack.error('WTF?');
				end
				if ( age[parent1] == age[parent2] ) then
					print('What a coincidence! Parents with the exact same age.');
					olderParent = parent1;
				elseif ( age[parent1] < age[parent2] ) then
					olderParent = parent1;
				else
					olderParent = parent2;
				end
			end
			dwarf.name.words[0] = olderParent.name.words[0];
			dwarf.name.words[1] = olderParent.name.words[1];
		end
		
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
		
		if ( nameScheme == 'default' ) then
			detectAndResolveConflicts(dwarf);
			sortName(dwarf);
			--only handleNewName when their name is finalized!
			handleNewName(dwarf);
		end
		
		local newNameString = dfhack.TranslateName(dwarf.name);
		
		if ( oldNameString ~= newNameString ) then
			print("old name = " .. oldNameString);
			print("new name = " .. newNameString);
			print();
		end
	end
	
	for index,dwarf in pairs(allUnits) do
		helper(dwarf);
	end
	
	local influence = {};
	function getBoss(unit)
		local name0 = unit.name.words[0];
		local name1 = unit.name.words[1];
		local leader0 = nameLeader[name0];
		local leader1 = nameLeader[name1];
		
		if ( leader0 == unit ) then
			return leader1;
		end
		if ( leader1 == unit ) then
			return leader0;
		end
		
		dfhack.error("WTF?");
	end
	
	function computeInfluence(name)
		local leader = nameLeader[name];
		if ( leader == nil ) then
			--influence[] = 0;
			return 0;
		end
		
		local otherName = leader.name.words[0];
		if ( otherName == name ) then
			otherName = leader.name.words[1];
		end
		
		local inf = influence[leader] or 0;
		inf = inf + (aliveNameHistogram[name] or 0);
		influence[leader] = inf;
		
		local boss = getBoss(leader);
		
		if ( boss == leader ) then
			local count2 = aliveNameHistogram[otherName] or 0;
			influence[leader] = inf + count2;
			return influence[leader];
		end
		
		--he's our boss: add our influence to him, all the way up
		while(true) do
			local count1 = influence[boss] or 0;
			influence[boss] = count1 + aliveNameHistogram[name];
			local lastBoss = boss;
			boss = getBoss(boss);
			if ( boss == lastBoss ) then
				break;
			end
		end
		
		return influence[leader];
	end
	
	for name,_ in pairs(allNames) do
		computeInfluence(name);
	end
	
	--print out the age of each name
	function printNameInformation()
		local count = 0;
		local newList = {};
		for name,_ in pairs(allNames) do
			newList[count] = name;
			count = count+1;
		end
		function ageLessThan(a,b)
			if ( a == b ) then
				do return false end;
			end
			
			local name1 = newList[a];
			local name2 = newList[b];
			local age1 = nil;
			local age2 = nil;
			
			if ( sortOutputBy == 'alphabetic' ) then
				--TODO: ------------------------------------------------------------------------------------this line for correct translations
				local str1 = df.global.world.raws.language.translations[0].words[name1].value;
				local str2 = df.global.world.raws.language.translations[0].words[name2].value;
				if ( doReverseOutputOrder ) then
					do return str2 < str1 end;
				else
					do return str1 < str2 end;
				end
			elseif ( sortOutputBy == 'aliveUses' ) then
				age1 = aliveNameHistogram[name1];
				age2 = aliveNameHistogram[name2];
			elseif ( sortOutputBy == 'uses' ) then
				age1 = nameHistogram[name1];
				age2 = nameHistogram[name2];
			elseif ( sortOutputBy == 'fortUses' ) then
				age1 = localNameHistogram[name1];
				age2 = localNameHistogram[name2];
			elseif ( sortOutputBy == 'fortAliveUses' ) then
				age1 = localAliveNameHistogram[name1];
				age2 = localAliveNameHistogram[name2];
			elseif ( sortOutputBy == 'nameAge' ) then
				age1 = nameAge[name1];
				age2 = nameAge[name2];
			elseif ( sortOutputBy == 'leaderAge' ) then
				if ( nameLeader[name1] == nil ) then
					age1 = nil;
				else
					age1 = age[nameLeader[name1]];
				end
				if ( nameLeader[name2] == nil ) then
					age2 = nil;
				else
					age2 = age[nameLeader[name2]];
				end
			elseif ( sortOutputBy == 'fortLeaderAge' ) then
				if ( localNameLeader[name1] == nil ) then
					age1 = nil;
				else
					age1 = age[localNameLeader[name1]];
				end
				if ( localNameLeader[name2] == nil ) then
					age2 = nil;
				else
					age2 = age[localNameLeader[name2]];
				end
			elseif ( sortOutputBy == 'fortNameAge' ) then
				if ( localNameFounder[name1] == nil ) then
					age1 = nil;
				else
					age1 = age[localNameFounder[name1]];
				end
				if ( localNameFounder[name2] == nil ) then
					age2 = nil;
				else
					age2 = age[localNameFounder[name2]];
				end
			elseif ( sortOutputBy == 'influence') then
				if ( nameLeader[name1] == nil ) then
					age1 = nil;
				else
					age1 = influence[nameLeader[name1]];
				end
				if ( nameLeader[name2] == nil ) then
					age2 = nil;
				else
					age2 = influence[nameLeader[name2]];
				end
			else
				dfhack.error('Invalid sortOutputBy: "' .. sortOutputBy .. '"');
			end
			
			if ( age1 == nil and age2 == nil ) then
				do return false end;
			end
			
			if ( doReverseOutputOrder ) then
				if ( age2 == nil ) then
					do return true end;
				end
				if ( age1 == nil ) then
					do return false end;
				end
			else
				--not applicables first
				if ( age2 == nil ) then
					do return false end;
				end
				if ( age1 == nil ) then
					do return true end;
				end
			end
			
			if ( doReverseOutputOrder ) then
				local temp = age1;
				age1 = age2;
				age2 = temp;
			end
			
			if (age1 < age2) then
				do return true end;
			elseif (age1 == age2) then
				--TODO: other orderings?
				--mergesort is stable, so this will be consistent with the current ordering
				do return false end;
			else
				--age1 > age2
				do return false end;
			end
			dfhack.error("This should not be reachable.");
		end
		sort(newList, ageLessThan, 0, count);
		
		if ( outputType == 'printAllNames' ) then
			print("Printing all names:");
		elseif (outputType == 'printFortNames' ) then
			print("Printing all names represented in this fort at some point in the past or present:");
		elseif (outputType == 'printAllAliveNames') then
			print("Printing all names with at least one living dwarf:");
		elseif (outputType == 'printFortAliveNames') then
			print("Printing all names with at least one living dwarf in the current fort:");
		else
			dfhack.error('Invalid output type: "' .. outputType .. '"');
		end
		local sortOutputByStr = nil;
		if ( sortOutputBy == 'alphabetic' ) then
			sortOutputByStr = 'alphabetically';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', from Z to A';
			else
				sortOutputByStr = sortOutputByStr .. ', from A to Z';
			end
		elseif ( sortOutputBy == 'aliveUses' ) then
			sortOutputByStr = 'by number of living dwarves with the name';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', most common names last';
			else
				sortOutputByStr = sortOutputByStr .. ', most common names first';
			end
		elseif ( sortOutputBy == 'uses' ) then
			sortOutputByStr = 'by number of dwarves living or dead who have had the name';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', most common names last';
			else
				sortOutputByStr = sortOutputByStr .. ', most common names first';
			end
		elseif ( sortOutputBy == 'fortUses' ) then
			sortOutputByStr = 'by number of dwarves who have lived in the current fort who have the name, living or dead';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', most common names last';
			else
				sortOutputByStr = sortOutputByStr .. ', most common names first';
			end
		elseif ( sortOutputBy == 'fortAliveUses' ) then
			sortOutputByStr = 'by number of living dwarves in the current fort who have the name';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', most common names last';
			else
				sortOutputByStr = sortOutputByStr .. ', most common names first';
			end
		elseif ( sortOutputBy == 'nameAge' ) then
			sortOutputByStr = 'by time since the first dwarf to have the name';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', oldest names last';
			else
				sortOutputByStr = sortOutputByStr .. ', oldest names first';
			end
		elseif ( sortOutputBy == 'leaderAge' ) then
			sortOutputByStr = 'by age of the eldest dwarf with the name';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', oldest last';
			else
				sortOutputByStr = sortOutputByStr .. ', oldest first';
			end
		elseif ( sortOutputBy == 'fortLeaderAge' ) then
			sortOutputByStr = 'by age of the eldest dwarf in the current fort with the name';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', oldest last';
			else
				sortOutputByStr = sortOutputByStr .. ', oldest first';
			end
		elseif ( sortOutputBy == 'fortNameAge' ) then
			sortOutputByStr = 'by time since the birth of the first dwarf who lived in the current fort with the name';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', oldest last';
			else
				sortOutputByStr = sortOutputByStr .. ', oldest first';
			end
		--[[elseif ( sortOutputBy == '' ) then
			sortOutputByStr = '';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. '';
			else
				sortOutputByStr = sortOutputByStr .. '';
			end--]]
		elseif ( sortOutputBy == 'influence') then
			sortOutputByStr = 'by level of influence';
			if ( doReverseOutputOrder ) then
				sortOutputByStr = sortOutputByStr .. ', most influential last';
			else
				sortOutputByStr = sortOutputByStr .. ', most influential first';
			end
		else
			dfhack.error('Invalid sortOutputBy: "' .. sortOutputBy .. '"');
		end
		if ( sortOutputByStr == nil ) then
			dfhack.error('sortOutputByStr is nil');
		end
		print("Sorting " .. sortOutputByStr);
		function helper(i)
			local name = newList[i];
			--print(name);
			if ( name == -1 ) then
				return;
			end
			
			if ( outputType == 'printAllNames' ) then
				--print everyone
			elseif (outputType == 'printFortNames') then
				--print only fort
				if ( localNameFounder[name] == nil ) then
					return;
				end
			elseif (outputType == 'printAllAliveNames') then
				if ( nameLeader[name] == nil ) then
					return;
				end
			elseif (outputType == 'printFortAliveNames') then
				if ( localNameLeader[name] == nil ) then
					return;
				end
			else
				dfhack.error('WTF?');
			end
			
			local leader = nameLeader[name];
			if ( (leader == nil) or (leader ~= getBoss(leader)) ) then
				return;
			end
			
			local str = df.global.world.raws.language.translations[0].words[name].value;
			local temp = 
			print(string.format("    family %-10s: uses = %-4s, aliveUses = %4s, localAliveUses = %4s",
				str,
				tostring(nameHistogram[name]),
				tostring(aliveNameHistogram[name]),
				tostring(localAliveNameHistogram[name])));
			
			print(string.format("        founded in %-4.2f by %s",
				nameAge[name]/ticksPerYear,
				dfhack.TranslateName(nameFounder[name].name)));
			if ( nameLeader[name] ~= nil ) then
				if ( true ) then
					print(string.format("        led by %s, born %-4.2f, who has influence level %d",
						dfhack.TranslateName(nameLeader[name].name),
						age[nameLeader[name]]/ticksPerYear,
						influence[nameLeader[name]]));
				else
					print(string.format("        led by %s, born %-4.2f",
						dfhack.TranslateName(nameLeader[name].name),
						age[nameLeader[name]]/ticksPerYear));
				end
			end
			if ( localNameLeader[name] ~= nil ) then 
				print(string.format("        locally led by %s, born %-4.2f",
					dfhack.TranslateName(localNameLeader[name].name),
					age[localNameLeader[name]]/ticksPerYear));
			end
			print();
		end
		for i=0,count-1 do
			helper(i);
		end
	end
	
	if ( outputType ~= 'none' ) then
		printNameInformation();
	end
end

--computeHeritage();
--dfhack.with_suspend(computeHeritage);


local usage =
	function()
		print('Usage: heritage [-nameScheme {schemeNameHere}]'
			..'\n    [-outputType {outputTypeHere}]'
			..'\n    [-sortBy {sortTypeHere}]'
			..'\n    [-reverse]'
			..'\nnameScheme, outputType, sortBy, and reverse are optional and may be used in any combination and in any order. Do not use any braces in the arguments. The default nameScheme is \'default\', the default outputType is printLocalNames, the default sortBy is fortAliveUses.'
				..'For full information on what does what, call heritage -h. For even fuller information, do this and also read the readme.'
			..'\nExamples:'
				..'\n    heritage -nameScheme default -outputType printFortAliveNames -sortOutputBy nameAge'
					..'\n        Choose last names based on the default scheme, output statistics on all names of living dwarves in the current fort, outputting the information on the oldest names first.'
				..'\n    heritage -nameScheme eldestParent -outputType printAllAliveNames -sortOutputBy aliveUses -reverse'
					..'\n        Dwarves inherit the last name of the older of their parents, output statistics on all names of living dwarves in the world, outputting the information on the rarest names first.'
			);
	end

--nameScheme can be default, eldestParent, motherName, fatherName
--[[
--TODO
	optional copy output to file
	family tree
	conflict handling
	all races option
	correct translation of names
	multisort
	full last name information
	one name from each parent (statically)
	dry run option
	influence complications
	worry about visiting nonlocal dwarves
	worry about twin age
	sort output by english translation
--]]

local arguments = {...};
local nameScheme = 'unknown';
local outputType = 'printFortNames';
local sortBy = 'fortAliveUses';
local reverse = false;
local prev = nil;
local cancelRepeat = false;
local repeatEvery = nil;
for i,v in pairs(arguments) do
	if ( prev == nil ) then
		if ( v == '-nameScheme' or v == '-outputType' or v == '-sortOutputBy' or v == '-repeatEvery' ) then
			prev = v;
		elseif ( v == '-reverse' ) then
			reverse = true;
		elseif ( v == '-cancelRepeat' ) then
			cancelRepeat = true;
		elseif ( v == '-h' or v == '-help' or v == '--help' ) then
			usage();
			print('-nameScheme');
			print('    default: get two names from parents names, which names you get depend on your birth order.');
			print('    eldestParent: your last name is the last name of your eldest parent.');
			print('    fatherName: your last name is the last name of your father.');
			print('    motherName: your last name is the last name of your mother.');
			print('-outputType');
			print('    none: do not print name statistics.'); --TODO: actual no output
			print('    printAllNames: print statistics about all names that any dwarf has had');
			print('    printFortNames: print statistics about all names that any dwarf in your fort has had');
			print('    printAllAliveNames: print statistics about all names that at least one living dwarf in the world has.');
			print('    printFortAliveNames: print statistics about all names of living dwarves in your fort.');
			print('-sortOutputBy');
			print('    alphabetic: sort printed names alphabetically.');
			print('    aliveUses: sort printed names by how many living dwarves have them.');
			print('    uses: sort printed names by how many dwarves have had them.');
			print('    fortUses: sort printed names by how many dwarves in your fort have had them.');
			print('    fortAliveUses: sort printed names by how many living dwarves in your fort have them.');
			print('    nameAge: sort printed names by time since the birth of the first dwarf to possess it.');
			print('    leaderAge: sort printed names by the age of the eldest living dwarf with the name.');
			print('    fortLeaderAge: sort printed names by the age of the eldest living dwarf in the fort with the name.');
			print('    fortNameAge: sort printed names by the time since the birth of the first dwarf in the fort with the name.');
			print('    influence: sort printed names by influence.');
			print('-reverse: reverse the specified sort order.');
			print('-repeatEvery');
			print('    year');
			print('    month');
			print('-cancelRepeat: cancels any scheduled future calling of this. Implied by -repeatEvery.');
			do return end;
		else
			print('Incorrect usage: "' .. v .. '"');
			usage();
			do return end;
		end
	elseif ( prev == '-nameScheme' ) then
		if ( v == 'default' or v == 'eldestParent' or v == 'motherName' or v == 'fatherName' ) then
			nameScheme = v;
		else
			print('Incorrect usage: "' .. v .. '"');
			usage();
			do return end;
		end
		prev = nil;
	elseif ( prev == '-outputType' ) then
		if ( v == 'none' or v == 'printAllNames' or v == 'printFortNames' or v == 'printAllAliveNames' or v == 'printFortAliveNames' ) then
			outputType = v;
		else
			print('Incorrect usage: "' .. v .. '"');
			usage();
			do return end;
		end
		prev = nil;
	elseif ( prev == '-sortOutputBy' ) then
		if ( v == 'alphabetic' or v == 'aliveUses' or v == 'uses' or v == 'fortUses' or v == 'fortAliveUses' or v == 'nameAge' or v == 'leaderAge' or v == 'fortLeaderAge' or v == 'fortNameAge' or v == 'influence' ) then
			sortBy = v;
		else
			print('Incorrect usage: "' .. v .. '"');
			usage();
			do return end;
		end
		prev = nil;
	elseif ( prev == '-repeatEvery' ) then
		if ( v == 'month' or v == 'year' ) then
			repeatEvery = v;
			cancelRepeat = true;
		else
			print('Incorrect usage: "' .. v .. '"');
			usage();
			do return end;
		end
		prev = nil;
	else
		print('Incorrect usage: "' .. v .. '"');
		usage();
		do return end;
	end
end

if ( prev ~= nil ) then
	print("Incorrect usage: you must specify a parameter.");
	usage();
	do return end;
end

--dfhack.with_suspend(computeHeritage, nameScheme, outputType, sortBy, reverse);

--global timer
if ( cancelRepeat ) then
	if ( timer ~= nil ) then
		dfhack.timeout_active(timer,nil);
	end
end

local tempFunction = function(dumbHelper)
		--computeHeritange(nameScheme, outputType, sortBy, reverse);
		dfhack.with_suspend(computeHeritage, nameScheme, outputType, sortBy, reverse);
		
		function dumb()
			dumbHelper(dumbHelper);
		end
		
		if ( repeatEvery == 'year' ) then
			timer = dfhack.timeout(1,'years',dumb);
		elseif ( repeatEvery == 'month' ) then
			timer = dfhack.timeout(1,'months',dumb);
		elseif ( repeatEvery == nil ) then
			--dfhack.with_suspend(computeHeritage, nameScheme, outputType, sortBy, reverse);
		else
			dfhack.error("Error.");
		end
	end

tempFunction(tempFunction);
