package {
	import flash.display.*;
	import flash.events.*;
	import flash.text.*;
	import flash.geom.*;
	import flash.utils.getTimer;
	import flash.media.Sound;
	import flash.media.SoundChannel;
	
	public class Racing extends MovieClip {
		
		// constants
		static const maxSpeed:Number = .3;
		static const accel:Number = .0002;
		static const decel:Number = .0003;
		static const turnSpeed:Number = .18;
		
		// game variables
		private var arrowLeft, arrowRight, arrowUp, arrowDown:Boolean;
		private var lastTime:int;
		private var gameStartTime:int;
		private var speed:Number;
		private var gameMode:String;
		private var waypoints:Array;
		private var currentSound:Object;
		
		// sounds
		static const theBrakestopSound:BrakestopSound = new BrakestopSound();
		static const theDriveSound:DriveSound = new DriveSound();
		static const theGoSound:GoSound = new GoSound();
		static const theOffroadSound:OffroadSound = new OffroadSound();
		static const theReadysetSound:ReadysetSound = new ReadysetSound();
		static const theSideSound:SideSound = new SideSound();
		private var driveSoundChannel:SoundChannel;
		
		public function startRacing() {
			
			// get list of waypoints
			findWaypoints();
			
			// add listeners
			this.addEventListener(Event.ENTER_FRAME,gameLoop);
			stage.addEventListener(KeyboardEvent.KEY_DOWN,keyDownFunction);
			stage.addEventListener(KeyboardEvent.KEY_UP,keyUpFunction);
			
			// set up game variables
			speed = 0;
			gameMode = "wait";
			timeDisplay.text = "";
			gameStartTime = getTimer()+3000;
			centerMap();
		}
		
		// look at all gamesprite children and remember waypoints
		public function findWaypoints() {
			waypoints = new Array();
			for(var i=0;i<gamesprite.numChildren;i++) {
				var mc = gamesprite.getChildAt(i);
				if (mc is Waypoint) {
					// add to array and make invisible
					waypoints.push(new Point(mc.x, mc.y));
					mc.visible = false;
				}
			}
		}

		// note key presses, set properties
		public function keyDownFunction(event:KeyboardEvent) {
			if (event.keyCode == 37) {
				arrowLeft = true;
			} else if (event.keyCode == 39) {
				arrowRight = true;
			} else if (event.keyCode == 38) {
				arrowUp = true;
			} else if (event.keyCode == 40) {
				arrowDown = true;
			}
		}
		
		public function keyUpFunction(event:KeyboardEvent) {
			if (event.keyCode == 37) {
				arrowLeft = false;
			} else if (event.keyCode == 39) {
				arrowRight = false;
			} else if (event.keyCode == 38) {
				arrowUp = false;
			} else if (event.keyCode == 40) {
				arrowDown = false;
			}
		}

		// main game code
		public function gameLoop(event:Event) {
			
			// calculate time passed
			if (lastTime == 0) lastTime = getTimer();
			var timeDiff:int = getTimer()-lastTime;
			lastTime += timeDiff;
			
			// only move car if in race mode
			if (gameMode == "race") {
				// rotate left or right
				if (arrowLeft) {
					gamesprite.car.rotation -= (speed+.1)*turnSpeed*timeDiff;
				}
				if (arrowRight) {
					gamesprite.car.rotation += (speed+.1)*turnSpeed*timeDiff;
				}
			
				// accelerate car
				if (arrowUp) {
					speed += accel*timeDiff;
					if (speed > maxSpeed) speed = maxSpeed;
				} else if (arrowDown) {
					speed -= accel*timeDiff;
					if (speed < -maxSpeed) speed = -maxSpeed;
					
				// no arrow pressed, so slow down
				} else if (speed > 0) {
					speed -= decel*timeDiff;
					if (speed < 0) speed = 0;
				} else if (speed < 0) {
					speed += decel*timeDiff;
					if (speed > 0) speed = 0;
				}
				
				// if moving, then move car and check status
				if (speed != 0) {
					moveCar(timeDiff);
					centerMap();
					checkWaypoints();
					checkFinishLine();
				}
			}
			
			// update time and check for end of game
			showTime();
		}
		
		public function moveCar(timeDiff:Number) {
			
			// get current position
			var carPos:Point = new Point(gamesprite.car.x, gamesprite.car.y);
			
			// calculate change
			var carAngle:Number = gamesprite.car.rotation;
			var carAngleRadians:Number = (carAngle/360)*(2.0*Math.PI);
			var carMove:Number = speed*timeDiff;
			var dx:Number = Math.cos(carAngleRadians)*carMove;
			var dy:Number = Math.sin(carAngleRadians)*carMove;
			
			// assume we'll use drive sound
			var newSound:Object = theDriveSound;
			
			// see if car is NOT on the road
			if (!gamesprite.road.hitTestPoint(carPos.x+dx+gamesprite.x, carPos.y+dy+gamesprite.y, true)) {
		
				// see if car is on the side
				if (gamesprite.side.hitTestPoint(carPos.x+dx+gamesprite.x, carPos.y+dy+gamesprite.y, true)) {
					// use special sound, reduce speed
					newSound = theSideSound;
					speed *= 1.0-.001*timeDiff;
				} else {
					// use special sound, reduce speed
					newSound = theOffroadSound;
					speed *= 1.0-.005*timeDiff;
				}
			}
			
			// set new position of car
			gamesprite.car.x = carPos.x+dx;
			gamesprite.car.y = carPos.y+dy;
		
			// if not moving, forget about drive sound
			if (!arrowUp && !arrowDown) {
				newSound = null;
			}
			
			// if a new sound, switch sound
			if (newSound != currentSound) {
				if (driveSoundChannel != null) {
					driveSoundChannel.stop();
				}
				currentSound = newSound;
				if (currentSound != null) {
					driveSoundChannel = currentSound.play(0,9999);
				}
			}
		}
				
		// see if close enough to waypoint
		public function checkWaypoints() {
			for(var i:int=waypoints.length-1;i>=0;i--) {
				if (Point.distance(waypoints[i], new Point(gamesprite.car.x, gamesprite.car.y)) < 150) {
					waypoints.splice(i,1);
				}
			}
		}
		
		// see if crossed finish line
		public function checkFinishLine() {
			
			// only if all waypoints have been hit
			if (waypoints.length > 0) return;
			
			if (gamesprite.car.y < gamesprite.finish.y) {
				endGame();
			}
		}
		
		// update the time shown
		public function showTime() {
			var gameTime:int = getTimer()-gameStartTime;
			
			// if in wait mode, show countdown clock
			if (gameMode == "wait") {
				if (gameTime < 0) {
					// show 3, 2, 1
					var newNum:String = String(Math.abs(Math.floor(gameTime/1000)));
					if (countdown.text != newNum) {
						countdown.text = newNum;
						playSound(theReadysetSound);
					}
				} else {
					// count down over, go to race mode
					gameMode = "race";
					countdown.text = "";
					playSound(theGoSound);
				}
				
			// show time
			} else {
				timeDisplay.text = clockTime(gameTime);
			}
		}
		
		// convert to time format
		public function clockTime(ms:int):String {
			var seconds:int = Math.floor(ms/1000);
			var minutes:int = Math.floor(seconds/60);
			seconds -= minutes*60;
			var timeString:String = minutes+":"+String(seconds+100).substr(1,2);
			return timeString;
		}
		
		
		// make sure car stays at center of screen
		public function centerMap() {
			gamesprite.x = -gamesprite.car.x + 275;
			gamesprite.y = -gamesprite.car.y + 200;
		}
		
		// game over, remove listeners
		public function endGame() {
			driveSoundChannel.stop();
			playSound(theBrakestopSound);
			this.removeEventListener(Event.ENTER_FRAME,gameLoop);
			stage.removeEventListener(KeyboardEvent.KEY_DOWN,keyDownFunction);
			stage.removeEventListener(KeyboardEvent.KEY_UP,keyUpFunction);
			gotoAndStop("gameover");
		}
		
		// show time on final screen
		public function showFinalMessage() {
			showTime();
			var finalDisplay:String = "";
			finalDisplay += "Time: "+timeDisplay.text+"\n";
			finalMessage.text = finalDisplay;
		}

		public function playSound(soundObject:Object) {
			var channel:SoundChannel = soundObject.play(0);
		}

	}
		
}
