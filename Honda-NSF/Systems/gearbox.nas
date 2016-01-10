###############################################################################################
#		Idea from DetlefF. and LesterB.
#		written by Lake of Constance Hangar :: M.Kraus
#		BMW S 1000 RR for Flightgear September 2014
#		This file is licenced under the terms of the GNU General Public Licence V2 or later
############################################################################################### 

var fuel = props.globals.getNode("consumables/fuel/tank/level-m3");
var fuel_lev = 0;
var fuel_weight = props.globals.getNode("consumables/fuel/total-fuel-lbs"); # max 31lbs
var running = props.globals.getNode("/engines/engine/running");
var gear = props.globals.getNode("/engines/engine/gear");
var gearsound = props.globals.initNode("/engines/engine/gear-sound",0,"DOUBLE");
var fastcircuit = props.globals.getNode("/controls/flight/flaps");
var clutch = props.globals.getNode("/engines/engine/clutch");
var secclutchcontrol = props.globals.getNode("/devices/status/keyboard/ctrl");
var killed = props.globals.getNode("/engines/engine/killed");
var rpm = props.globals.getNode("/engines/engine/rpm");
var propulsion = props.globals.getNode("/engines/engine/propulsion");
var throttle = props.globals.getNode("/controls/flight/throttle-on-elev-axis");
var lastthrottle = 0;
var lastgear = 0;
var lastfastcircuit = 0;
var engine_brake = props.globals.getNode("/engines/engine[0]/brake-engine");
var engine_rpm_regulation = props.globals.getNode("/engines/engine[0]/rpm_regulation");
var weight = props.globals.getNode("/sim/weight/weight-lb"); # max. 230 lbs
var inertia = 0;
var vmax = 0;
var looptime = 0.1;
var lastrpm = 0;
var transmissionpower = 0;
var minrpm = 3200;
var maxrpm = 14000;
var newrpm = 0;
var clutchrpm = 0;
var maxhealth = 40; # for the engine killing, higher is longer live while overspeed rpm
var speedlimiter = props.globals.getNode("/instrumentation/Honda-NSF/speed-indicator/speed-limiter");
var speedlimstate = props.globals.getNode("/instrumentation/Honda-NSF/speed-indicator/speed-limiter-switch");
var speed = 0;
var gspeed = 0;
var ascon = props.globals.initNode("/controls/Honda-NSF/ASC/on-off",1,"BOOL");

###########################################################################

var loop = func {

	var msec = getprop("/gear/gear/rollspeed-ms") or 0;
	var kmh = msec*3600/1000;
	var gefahrenem = getprop("/instrumentation/Honda-NSF/distance-calculator/mzaehler") or 0;
	var tagesm = getprop("/instrumentation/Honda-NSF/distance-calculator/dmzaehler") or 0;
	gefahrenem = gefahrenem + msec/8*1.16;  # 0.125 sec * 8 / 1.16 correction value for the wheel dimension
	tagesm = tagesm + msec/8*1.16;
	setprop("/instrumentation/Honda-NSF/distance-calculator/mzaehler", gefahrenem);
	setprop("/instrumentation/Honda-NSF/distance-calculator/dmzaehler", tagesm);
	
	#help_win.write(sprintf("Geschwindigkeit in m/s: %.2f Gesamt m: %.1f", kmh, gefahrenem));

	# properties for ABS and ASC at the bottom of this script
	var comp_m = getprop("/gear/gear[1]/compression-m") or 0;
	var brake_ctrl_left = getprop("/controls/gear/brake-left") or 0;
	var brake_ctrl_right = getprop("/controls/gear/brake-right") or 0;
	
	# second possibility for clutch control backspace key is setting in the BMW-S-1000-RR-set.xml
	if(secclutchcontrol.getBoolValue()){
		clutch.setValue(1);
	}else{
		clutch.setValue(0);
	}
	
	#gspeed = getprop("/instrumentation/airspeed-indicator/indicated-speed-kt") or 0;
	gspeed = getprop("/velocities/groundspeed-kt") or 0;
	var bwspeed = getprop("/gear/gear[1]/rollspeed-ms") or 0;
	bwspeed = bwspeed*2.23694; # meter per secondes to miles per hour
	
	# drive with gears
	# clutch control
	gearsound.setValue(0);
	if (lastfastcircuit != fastcircuit.getValue()){
			###### fastcircuit without clutch
			if(fastcircuit.getValue() == 0){
			    if(bwspeed < 2){
					gear.setValue(0);
				}else{
					gear.setValue(1);
				}
				gearsound.setValue(1);
			}else if(fastcircuit.getValue() > 0 and fastcircuit.getValue() < 0.11 ){
				gear.setValue(1);
				gearsound.setValue(1);
			}else if(fastcircuit.getValue() > 0.11 and fastcircuit.getValue() < 0.21){
				gear.setValue(2);
				gearsound.setValue(1);
			}else if(fastcircuit.getValue() > 0.21 and fastcircuit.getValue() < 0.31){
				gear.setValue(3);
				gearsound.setValue(1);
			}else if(fastcircuit.getValue() > 0.31 and fastcircuit.getValue() < 0.41){
				gear.setValue(4);
				gearsound.setValue(1);
			}else if(fastcircuit.getValue() > 0.41 and fastcircuit.getValue() < 0.51){
				gear.setValue(5);
				gearsound.setValue(1);
			}else if(fastcircuit.getValue() > 0.51 and fastcircuit.getValue() < 0.61){
				gear.setValue(6);
				gearsound.setValue(1);
			}
	} else if(gear.getValue() != lastgear and clutch.getValue() == 1){
		###### switch up and down with clutch
		gearsound.setValue(1);
	} else { 
		gear.setValue(lastgear);
	}

	# ----------- ENGINE IS RUNNING --------------
	if(running.getValue() == 1){

		# calculate the inertia
		#inertia = (fuel_weight.getValue() + weight.getValue())/245; # 245 max. weight and fuel
		
		# overspeed the engine
		if(rpm.getValue() > maxrpm+200){
			if(engine_rpm_regulation.getValue() < 1){
				killed.setValue(killed.getValue() + 1/maxhealth);
			}
			if(killed.getValue() >= 1)rpm.setValue(40000);
		}
		if(killed.getValue() >= 1){
			running.setValue(0);
			killed.setValue(1);
			propulsion.setValue(0);
			interpolate("/engines/engine/rpm" , 0, 3);
			engine_brake.setValue(0.7);
		}

		# max speed per gear in kts
		if (gear.getValue() == 0) {
			vmax = 0;
			fastcircuit.setValue(0);
		} else if (gear.getValue() == 1) {
			vmax = 35;
			fastcircuit.setValue(0.1);
		} else if (gear.getValue() == 2) {
			vmax =  45;
			fastcircuit.setValue(0.2);
		} else if (gear.getValue() == 3) {
			vmax = 55;
			fastcircuit.setValue(0.3);
		} else if (gear.getValue() == 4) {
			vmax = 65;
			fastcircuit.setValue(0.4);
		} else if (gear.getValue() == 5) {
			vmax = 75;
			fastcircuit.setValue(0.5);
		} else if (gear.getValue() == 6) {
			vmax = 85;
			fastcircuit.setValue(0.6);
		}

		# everthing is ok - let him go
		if (gear.getValue() > 0 and clutch.getValue() == 0) {
			if(fastcircuit.getValue() == 0.1){
			  transmissionpower = throttle.getValue()*2;
			  setprop("/sim/weight[1]/weight-lb", throttle.getValue()*300);
			}else if(fastcircuit.getValue() == 0.2){
			  transmissionpower = 0.9*throttle.getValue()-propulsion.getValue()/maxrpm;
			}else if(fastcircuit.getValue() == 0.3){
			  transmissionpower = 0.7*throttle.getValue()-propulsion.getValue()/maxrpm;
			}else if(fastcircuit.getValue() == 0.4){
			  transmissionpower = 0.6*throttle.getValue()-propulsion.getValue()/maxrpm;
			}else if(fastcircuit.getValue() == 0.5){
			  transmissionpower = 0.45*throttle.getValue()-propulsion.getValue()/maxrpm;
			}else{
			  transmissionpower = 0.38*throttle.getValue()-propulsion.getValue()/maxrpm;
			}
			transmissionpower = transmissionpower * (1- killed.getValue());
			propulsion.setValue(transmissionpower);
			
			newrpm = (bwspeed < 1 and throttle.getValue() > 0.1) ? throttle.getValue()*(maxrpm+250) : (maxrpm+250)/vmax*bwspeed;
			if(lastgear == 0 and newrpm < lastrpm){
			    newrpm = lastrpm;
				#help_win.write(sprintf("lastrpm: %.2f newrpm: %.2f", lastrpm, rpm.getValue()));
			}else if(newrpm < minrpm){
				newrpm = minrpm;
			}
			rpm.setValue(newrpm);
			
			# killing engine with the wrong gear and backwheel on earth
			if (gear.getValue() > 2 and bwspeed < 10 and comp_m > 0.2) {
						running.setValue(0);
						propulsion.setValue(0);
			}

		} else {
			rpm.setValue(throttle.getValue()*(maxrpm+1400));
			propulsion.setValue(0);
		}
		
		# brake engine feeling at decrease throttle
		if(rpm.getValue() > 2000 and clutch.getValue() == 1){
			clutchrpm = lastrpm + 600;
			rpm.setValue(clutchrpm);
		}
		
		speed = getprop("/instrumentation/Honda-NSF/speed-indicator/speed-meter");
		
		if(bwspeed > 3 and (lastthrottle > throttle.getValue() or throttle.getValue() <= 0) and clutch.getValue() == 0 and gear.getValue() > 0){ 
			propulsion.setValue(0);
			engine_brake.setValue(0.2);
		}else if(speedlimiter.getValue() < speed and speedlimstate.getBoolValue() == 1){
			propulsion.setValue(0);
			engine_brake.setValue(1);
		}else{
			engine_brake.setValue(0);
		}
		
		# Automatic RPM overspeed regulation
		if(rpm.getValue() > maxrpm-400){
			if(engine_rpm_regulation.getValue() == 1 ){
				propulsion.setValue(0);
				if (bwspeed > 20) engine_brake.setValue(1.0);
				rpm.setValue(maxrpm-500);
				setprop("/controls/Honda-NSF/ctrl-light-overspeed", 1);
			}else{
				setprop("/controls/Honda-NSF/ctrl-light-overspeed", 1);
			}
	
		}else{
			setprop("/controls/Honda-NSF/ctrl-light-overspeed", 0);
		}


		if((rpm.getValue()) < minrpm){
			rpm.setValue(minrpm);  # place after the rpm calculation
		}

		if (fuel.getValue() < 0.000002) {
			running.setValue(0);
		}
		else {
			fuel_lev = fuel.getValue();
			setprop("/controls/fuel/remember-level", fuel.getValue()); # save it for restart
			fuel.setValue(fuel_lev - (throttle.getValue()+0.1)*0.000001);
		}
		
		#-------------- ENGINE RUNNING END --------------------
		
	} else{
	  if(rpm.getValue() > 2000){
	  	interpolate("/engines/engine/rpm" , 0, 3);
	  }
	  propulsion.setValue(0);
	}
	
	if(getprop("instrumentation/Honda-NSF/speed-indicator/selection")){
		help_win_gear.write(sprintf(" %.0f / %.0f mph", gear.getValue(), speed));
	}else{
		help_win_gear.write(sprintf(" %.0f / %.0f km/h", gear.getValue(), speed));
	}
	
	
	#-------------- ENGINE END --------------------
	
	# Anti - blog brake regulation
	if(comp_m < 0.05 and brake_ctrl_right > 0.5 and brake_ctrl_left > 0.5 and gspeed > 70){
		setprop("/controls/Honda-NSF/ABS/ctrl-light", 1);
		setprop("/controls/Honda-NSF/ABS/brake-right", brake_ctrl_right*0.34);
		setprop("/controls/Honda-NSF/ABS/brake-left", brake_ctrl_left*0.34);		
	}else{
		setprop("/controls/Honda-NSF/ABS/ctrl-light", 0);
		setprop("/controls/Honda-NSF/ABS/brake-right", brake_ctrl_right);
		setprop("/controls/Honda-NSF/ABS/brake-left", brake_ctrl_left);
	}
	
	lastthrottle = throttle.getValue();
	lastrpm = rpm.getValue();
	lastfastcircuit = fastcircuit.getValue();
	lastgear = gear.getValue();
	settimer (loop, 0.125);
}


loop();


