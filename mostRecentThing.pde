/*
based on specs here: glitch scarf git:
https://github.com/molleindustria/GlitchScarf/tree/master/data

actual serial communication: 
http://ayab-knitting.com/development/


This example takes knitting lines from a shifting images 
 so I can use processing drawing capabilities instead of dealing with arrays
 */


import processing.serial.*;  //Syntax Error - You may be mixing active and static modes. ?????
import processing.event.KeyEvent;
import processing.video.*;

Capture video;
int rownum = 0;

Serial myPort;  
int portNumber = 3;

boolean connected = false;
boolean ready = false;
boolean handshake = false;
boolean resetMessage = false;

boolean beginning;
int beginningLines;

int IMAGE_WIDTH = 200;
int TOT_NEEDLES = 200;
//the current line that will be added to the "scarf"
int[] lineData = new int[IMAGE_WIDTH];

boolean clearCanvas= false;
boolean drawMode = false;
boolean moved = false;
boolean nextLine = false;

int startNeedle = 0;//TOT_NEEDLES/2+IMAGE_WIDTH/2; //this is good
int stopNeedle = 199;//TOT_NEEDLES/2-IMAGE_WIDTH/2;  //this is not
//(Range: 0..198)

void setup(){
  size(200,1000);
  video = new Capture(this,200,1000);
  video.start();
  
  // List all the available serial ports: 
  printArray(Serial.list());
  if (Serial.list().length>portNumber) {
    myPort = new Serial(this, Serial.list()[portNumber], 115200); 
    myPort.bufferUntil('\n'); 
    connected = true;
  } else
  {
    println("Error there's no port "+portNumber);
  }
  
  beginning = true;
  beginningLines = 0;
  
  for (int i = 0; i<IMAGE_WIDTH; i++)
  {
    lineData[i] = 0;
  }
  
  background(0); 
  clearCanvas = true;

  //KEYS = new boolean[255]; //i dont know what this does

  drawMode = false; //i dont know what this does yet....
}

void draw(){
  //new stuff from glitchscarf
  background(0);
  moved = false;
  
  if (clearCanvas) {
    clearCanvas = false;
    canvas.background(white);
  }
  
 
  
  
  //old stuff my stuff that works
  PImage img = createImage(200,1000,ARGB);
  img.loadPixels();
 if (video.available()){
   video.read();
   video.filter(THRESHOLD);
 }
 if (rownum>=999){
   rownum =0;
 }
 for (int i = 0+(rownum*200); i < (video.width+(rownum*200)); i++){
   if (video.pixels[i] == color(0,0,0)){
     print(0);
     img.pixels[i] = color(0,0,0);
     lineData[i] = 0;
   } else{
     print(1);
     img.pixels[i] = color(255,255,255);
     lineData[i] = 0;
   }  
 }
 println(255);
 //println(rownum);

 image(img,0,0);
 
 //new stuff from glitchscarf
 sendLine(rownum, lineData);
}

void keyPressed() {
  if (key == CODED) {
    if (keyCode == DOWN) {
      rownum++;
    }
    if (keyCode == ENTER) {
      rownum = 0;
      background(255);
    }
  }
}




////////////////////////////////////////////////// MACHINE COMMUNICATION STUFF
///I kept all of this from glitchscarf
//there is no arduino stuff provided so I'm assuming it works with whatever is already put on there by ayab


//takes an array of int, turns into bits splits into 25 bytes and sends it as command
public void sendLine(int lineNumber, int imageLine[]) {

  imageLine = reverse(imageLine);

  //line is the whole bed
  int[] line = new int[TOT_NEEDLES];

  //put the line in the center of the bed
  //int imgIndex = 0;
  int imgIndex = 0;

  for (int i=0; i<TOT_NEEDLES; i++) {
    //outside image
    //if (i<(TOT_NEEDLES/2 - IMAGE_WIDTH/2) || i>=(TOT_NEEDLES/2 + IMAGE_WIDTH/2) ) {
      if (i<0 || i>=IMAGE_WIDTH ) {
    
      line[i] = 0;
    } else {
      //inside image
      line[i] = imageLine[imgIndex];
      imgIndex++;
    }
  }

  //println("Centered line");
  //printArray(line);

  byte lineBytes[] = new byte[25];

  //pack it into an array of bytes
  for (int by = 0; by<25; by++) {
    int newByte = 0;

    for (int b = 0; b<8; b++) {
      int newBit = line[(by*8)+b] << b;
      //println("Bit shifted "+binary(newBit));
      newByte = newByte | newBit;
    }
    lineBytes[by] = byte(newByte);
  }//end line bytearray


  //init the byte array to send out
  byte out[] = new byte[29];

  for (int i=0; i<29; i++) {
    out[i] = 0;
  }

  //merge the array with command and flags with the line data
  out[0] = byte(0x42);
  out[1] = byte(lineNumber); //line number
  for (int i=0; i<25; i++) {
    out[2+i] = lineBytes[i];
    //println("what I actually send " +binary(out[2+i]));
  }

  out[27] = byte(0x00); //last line: 1 = job done
  out[28] = byte(0x00); //checksum (possibly not implemented

  if (connected) myPort.write(out);
  rownum++;
}




//function converting 010101010101010 to {0,1...} etc
//i dont think i needed this
public int[] stringToInt(String str) {
  int[] arr = new int[IMAGE_WIDTH]; 

  for (int i=0; i<IMAGE_WIDTH; i++) {
    if (str.charAt(i)=='0')
      arr[i] = 0;
    else
      arr[i] = 1;
  }

  return arr;
}

void onHandShake() {
  println("cnfInfo received: handshake successful");
  handshake = true;
  //automatically send a request
  reqStart();
}


void onInit(boolean isReady) {
  if (isReady) {
    currentLine = 0;
    ready = true;

    println("cnfStart/indInit positive: ready to start");
  } else if (!resetMessage) {
    println("cnfStart/indInit received: Reset the carriage");
    resetMessage = true;
    //TODO startKnitting change text
  }
}

//called when the carriage is at in the starting position
void onReset(boolean isReset) {
  if (isReset)
    reqStart();
}

public void startup() {
  println("Sending reqInfo");

  if (connected)
    myPort.write(0x03);

  ready = false;
  handshake = false;
  resetMessage = false;
}

public void reqStart() {
  //the reqStart has to be sent continuously until the carriage is ready
  //the first line request will initiate the knitting
  println("Sending reqStart");
  byte out[] = new byte[4];
  out[0] = byte(0x01);
  out[1] = byte(0x02); // 1 = machine type KH 910 , 2 = machine type of mine
  out[2] = byte(startNeedle); //start needle (Range: 0..198)
  out[3] = byte(stopNeedle); //stop needle (Range: 1..199)


  if (connected)
    myPort.write(out);
}


void serialEvent(Serial myPort){
  inString = "";

  byte[] inBuffer = new byte[8];

  if (connected)
    while (myPort.available () > 0) {
      inBuffer = myPort.readBytes();
      myPort.readBytes(inBuffer);
      //inBufferfinal = inBuffer;

      if (inBuffer != null) {
        for (int i=0; i<inBuffer.length; i++) {
          inString = inString + hex(inBuffer[i])+" , " ;
        }

        //println(hex(inBuffer[1])+" wtf");

        if (hex(inBuffer[0]).equals("C3")) {
          onHandShake();
        }

        if (hex(inBuffer[0]).equals("C1")) {

          if (hex(inBuffer[1]).equals("00")) 
            onInit(false);

          if (hex(inBuffer[1]).equals("01")) 
            onInit(true);
        }

        if (hex(inBuffer[0]).equals("84")) {

          if (hex(inBuffer[1]).equals("00")) 
            onReset(false);

          if (hex(inBuffer[1]).equals("01")) 
            onReset(true);
        }

        if (hex(inBuffer[0]).equals("82")) {
          onLineRequest(inBuffer[1]);
        }
      }
    }
}
}
