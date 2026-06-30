// ==========================================================
// PART 1: LIBRARIES & PINS SETUP
// ==========================================================
#include <Arduino.h>
#include <SPI.h>                 
#include <MFRC522.h>               
#include "tags.h"                

#include <BLEDevice.h>           
#include <BLEServer.h>           
#include <BLEUtils.h>            
#include <BLE2902.h>  

// --- NFC SPI Pins ---
#define RC522_SS 10               
#define RC522_RST 9
MFRC522 rfid(RC522_SS, RC522_RST);

// --- Motor Pins ---
#define STEP_X 5
#define DIR_X  4
#define EN_X   6
#define LIMIT_X 13

#define STEP_Y 16
#define DIR_Y  15
#define EN_Y   17
#define LIMIT_Y 14


// ==========================================================
// PART 2: GLOBAL VARIABLES & OBJECTS
// ==========================================================

// --- BLE Config ---
#define SERVICE_UUID        "4fafc201-1fb5-459e-8fcc-c5c9c331914b" 
#define CHARACTERISTIC_UUID "beb5483e-36e1-4688-b7f5-ea07361b26a8" 
BLEServer* pServer = NULL;                   
BLECharacteristic* pCharacteristic = NULL;    
bool deviceConnected = false;  

// --- Motor Config & States ---
const int MICROSTEP = 16;
const int STEPS_PER_REV = 200;
const float DIST_PER_REV = 40.0;
const float GRID_SIZE_MM = 30.0;
float CAL_X = 0.715;
float CAL_Y = 0.7485;
const long BASE_STEPS = (long)((STEPS_PER_REV * MICROSTEP) * (GRID_SIZE_MM / DIST_PER_REV));
const int Y_MAX = 14;

int curX = 0;
int curY = 0;   
volatile bool stopFlag = false; 
bool cmdStartPending = false;
bool cmdReturnHomePending = false;

// --- Game Logic States ---
int currentTurn = 1;                                                                         
bool p1Ready = false;
bool p2Ready = false;                                                                        
bool gameStarted = false;                                                                    
int p1TotalScore = 0;                                                                        
int p2TotalScore = 0;                                                                        
int turnCount = 1;
int skipTurnCount = 0;   

// --- Scanning States ---
bool isScanning = false;                                                                     
int scanTargetCount = 0;                                                                     
int currentScanCount = 0;
int scanStartX, scanStartY, scanStepX, scanStepY; 
bool waitingForAppInput = false;                                                             

// --- Tokens & Board Memory ---
const int MAX_TOKENS = 15;                                                                   
String tokens[MAX_TOKENS];                                                                   
int tokenIndexes[MAX_TOKENS];                                                                
int tokenScores[MAX_TOKENS];                                                                 
bool isBonusUsed[225];
String boardTokens[225];                                                                    
int boardScores[225];                                                                        
String usedUIDs[104];                                                                        
int usedUIDCount = 0;                                                                        
String tempRoundUIDs[MAX_TOKENS];

// ==========================================================
// PART 3: MOTOR CONTROL FUNCTIONS
// ==========================================================
void enableDrivers() {
  digitalWrite(EN_X, LOW); digitalWrite(EN_Y, LOW);
}

void disableDrivers() {
  digitalWrite(EN_X, HIGH); digitalWrite(EN_Y, HIGH);
}

void stepPulse(int pin, int d) {
  digitalWrite(pin, HIGH); delayMicroseconds(d);
  digitalWrite(pin, LOW); delayMicroseconds(d);
  static int count = 0;
  if (++count > 100) { yield(); count = 0; }
}

long stepsPerCell(float cal) { return (long)(BASE_STEPS * cal); }

void moveFastAxis(int stepPin, int dirPin, int &cur, int target, float cal, int speed) {
  long diff = target - cur;
  if (diff == 0 || stopFlag) return;
  long total = abs(diff) * stepsPerCell(cal);
  if (dirPin == DIR_Y) {
    digitalWrite(dirPin, diff > 0 ? LOW : HIGH);
  } else {
    digitalWrite(dirPin, diff > 0 ? HIGH : LOW);
  }
  for (long i = 0; i < total; i++) {
    if (stopFlag) return;
    if (i % 500 == 0) yield(); 
    int d = 400;
    if (total > 800) {
      if (i < 400) d = map(i, 0, 400, 400, speed);
      else if (i > total - 400) d = map(i, total - 400, total, speed, 400);
      else d = speed;
    } else {
      d = speed;
    }
    stepPulse(stepPin, d);
  }
  cur = target;
}

bool homeAxis(int stepPin, int dirPin, int limitPin, const char* name, bool dirLow) {
  Serial.print("Homing "); Serial.println(name);
  digitalWrite(dirPin, dirLow ? LOW : HIGH);
  unsigned long t = millis();
  while (digitalRead(limitPin) == HIGH) {
    if (stopFlag) return false;
    if (millis() - t > 30000) return false;
    stepPulse(stepPin, 900);
    yield(); 
  }
  delay(200);
  digitalWrite(dirPin, dirLow ? HIGH : LOW);
  for (int i = 0; i < 500; i++) stepPulse(stepPin, 1200);
  delay(200);
  digitalWrite(dirPin, dirLow ? LOW : HIGH);
  while (digitalRead(limitPin) == HIGH) {
    if (stopFlag) return false;
    stepPulse(stepPin, 1500);
    yield(); 
  }
  Serial.print(">> "); Serial.print(name); Serial.println(" Home Done");
  return true;
}

bool homeXY() {
  if (stopFlag) return false;
  if (!homeAxis(STEP_X, DIR_X, LIMIT_X, "X", true)) return false;
  curX = 0; 
  if (!homeAxis(STEP_Y, DIR_Y, LIMIT_Y, "Y", true)) return false;
  curY = Y_MAX; 
  Serial.println("HOME DONE: (X:0, Y:14)");
  return true;
}


// ==========================================================
// PART 4: GAME LOGIC & MATH FUNCTIONS
// ==========================================================
bool isUidAlreadyScanned(String uid) {
  for (int i = 0; i < usedUIDCount; i++) if (usedUIDs[i] == uid) return true;
  for (int i = 0; i < currentScanCount; i++) if (tempRoundUIDs[i] == uid) return true;
  return false;
}

String mapUidToToken(String uid) {
  for (int i = 0; i < TAG_COUNT; i++) if (uid == tags[i].uid) return tags[i].token;
  return "";                                 
}

int getTokenScore(String tok) {
  for (int i = 0; i < TAG_COUNT; i++) if (tok == tags[i].token) return tags[i].score;
  return 0;                                   
}

bool computeSimple(String expr, int &result) {
  expr.replace("x", "*"); expr.replace("÷", "/");
  int nums[15]; char ops[15];
  int numCount = 0, opCount = 0, current = 0;
  bool isParsingNum = false;
  for (int i = 0; i < (int)expr.length(); i++) {
    char c = expr[i];
    if (isdigit(c)) {
      current = current * 10 + (c - '0');
      isParsingNum = true;
    } else {
      if (isParsingNum) { nums[numCount++] = current; current = 0; isParsingNum = false; }
      ops[opCount++] = c;
    }
  }
  if (isParsingNum) nums[numCount++] = current;
  for (int i = 0; i < opCount; i++) {
    if (ops[i] == '*' || ops[i] == '/') {
      if (ops[i] == '*') nums[i] = nums[i] * nums[i + 1];
      else { 
        if (nums[i + 1] == 0 || nums[i] % nums[i + 1] != 0) return false;
        nums[i] = nums[i] / nums[i + 1]; 
      }
      for (int j = i + 1; j < numCount - 1; j++) nums[j] = nums[j + 1];
      for (int j = i; j < opCount - 1; j++) ops[j] = ops[j + 1];
      numCount--; opCount--; i--;
    }
  }
  int finalResult = nums[0];
  for (int i = 0; i < opCount; i++) {
    if (ops[i] == '+') finalResult += nums[i + 1];
    else if (ops[i] == '-') finalResult -= nums[i + 1];
  }
  result = finalResult; return true;
}

String getBonusType(int index) {
  int r = index / 15, c = index % 15;
  if ((r == 0 || r == 7 || r == 14) && (c == 0 || c == 7 || c == 14)) { 
    if (r == 7 && c == 7) return "STAR"; return "3W";                               
  }
  int yel[12][2] = {{1,1},{2,2},{3,3},{1,13},{2,12},{3,11},{13,1},{12,2},{11,3},{13,13},{12,12},{11,11}};
  for (int i = 0; i < 12; i++) if (yel[i][0] == r && yel[i][1] == c) return "2W";
  int blu[16][2] = {{1,5},{1,9},{5,1},{5,5},{5,9},{5,13},{9,1},{9,5},{9,9},{9,13},{13,5},{13,9},{4,4},{4,10},{10,10},{10,4}};
  for (int i = 0; i < 16; i++) if (blu[i][0] == r && blu[i][1] == c) return "3L";
  int ora[24][2] = {{0,3},{0,11},{2,6},{2,8},{3,0},{3,7},{3,14},{6,2},{6,6},{6,8},{6,12},{7,3},{7,11},{8,2},{8,6},{8,8},{8,12},{11,0},{11,7},{11,14},{12,6},{12,8},{14,3},{14,11}};
  for (int i = 0; i < 24; i++) if (ora[i][0] == r && ora[i][1] == c) return "2L";
  return "NONE";                               
}

int evaluateExpression() {             
  int eqCount = 0;
  for (int i = 0; i < scanTargetCount; i++) if (tokens[i] == "=") eqCount++;          
  if (eqCount == 0) return -1;
  int expectedValue = 0, segmentIndex = 0; String currentExpr = "";
  for (int i = 0; i <= scanTargetCount; i++) {
    if (i == scanTargetCount || tokens[i] == "=") { 
      if (currentExpr == "") return -1;
      int segmentValue = 0;
      if (!computeSimple(currentExpr, segmentValue)) return -1; 
      if (segmentIndex == 0) expectedValue = segmentValue;
      else if (segmentValue != expectedValue) return -1; 
      currentExpr = ""; segmentIndex++;
    } else currentExpr += tokens[i];
  }
  int roundScore = 0, equationMultiplier = 1;                
  for (int i = 0; i < scanTargetCount; i++) {
    int currentIdx = tokenIndexes[i], pieceScore = tokenScores[i];
    if (!isBonusUsed[currentIdx]) {           
      String bonus = getBonusType(currentIdx);
      if (bonus == "2L") pieceScore *= 2;    
      else if (bonus == "3L") pieceScore *= 3;
      else if (bonus == "STAR") pieceScore *= 3; 
      if (bonus == "2W") equationMultiplier *= 2;
      else if (bonus == "3W") equationMultiplier *= 3; 
    }
    roundScore += pieceScore;
  }

  int newTileCount = 0;
  for (int i = 0; i < scanTargetCount; i++) {
    if (tempRoundUIDs[i] != "OLD_TILE" && tempRoundUIDs[i] != "EMPTY" && tempRoundUIDs[i] != "") {
      newTileCount++;
    }
  }

  int finalScore = roundScore * equationMultiplier;
  if (newTileCount == 8) {
    finalScore += 40;
    Serial.println("🎉 BINGO BONUS! +40 Points added!");
  }

  return finalScore;
}


// ==========================================================
// PART 5: BLE COMMUNICATIONS & CALLBACKS
// ==========================================================
void sendToApp(String msg) {
  if (deviceConnected) {                      
    pCharacteristic->setValue(msg.c_str());
    pCharacteristic->notify();               
    Serial.println("Notify: " + msg);        
  }
}

void triggerGameOver(String reason) {
  gameStarted = false; isScanning = false; 
  stopFlag = false;         
  enableDrivers();
  homeXY();                 
  disableDrivers();         
  String winner = "DRAW";
  if (p1TotalScore > p2TotalScore) winner = "P1";
  else if (p2TotalScore > p1TotalScore) winner = "P2";
  sendToApp("GAME_OVER:" + winner + ":" + reason);
}

class MyCallbacks: public BLECharacteristicCallbacks {
  void onWrite(BLECharacteristic *pCharacteristic) {
    String rx = pCharacteristic->getValue().c_str(); 
    rx.trim();
    Serial.println("RX: " + rx);

    if (rx == "CMD:STOP") {
      stopFlag = true; isScanning = false;
      disableDrivers();
      sendToApp("MSG:STOPPED");
    }
    else if (rx.startsWith("CMD:CHOICE:")) { 
      if (waitingForAppInput) {              
        String chosenValue = rx.substring(11);
        chosenValue.trim();
        tokens[currentScanCount] = chosenValue; 
        waitingForAppInput = false;
        Serial.println("App choice: [" + chosenValue + "]");
        delay(500);
      }
    }
    else if (rx.indexOf("CMD:READY") != -1) { 
      if (!p1Ready) { p1Ready = true; sendToApp("STATUS:P1_READY"); } 
      else if (!p2Ready) { p2Ready = true; sendToApp("STATUS:P2_READY"); } 
      if (p1Ready && p2Ready) sendToApp("STATUS:ALL_READY");
    } 
    else if (rx.indexOf("REF:START") != -1) { 
      p1Ready = p2Ready = gameStarted = true;
      currentTurn = 1; turnCount = 1; p1TotalScore = p2TotalScore = 0;
      skipTurnCount = 0; usedUIDCount = 0;
      for (int i = 0; i < 225; i++) { 
        isBonusUsed[i] = false;
        boardTokens[i] = ""; 
        boardScores[i] = 0; 
      }
      stopFlag = false; cmdStartPending = true;   
      sendToApp("TURN:1"); 
      sendToApp("MSG:GAME_STARTED");
      sendToApp("LIGHT:OFF"); 
    }
    else if (rx.indexOf("REF:END_GAME") != -1) triggerGameOver("REFEREE_DECISION");
    else if (rx.indexOf("CMD:SUBMIT") != -1) sendToApp("LIGHT:YELLOW");
    else if (rx.startsWith("APPROVE:")) { 
      int sX, sY, eX, eY, tCount;
      if (sscanf(rx.c_str(), "APPROVE:X%dY%d:X%dY%d:%d", &sX, &sY, &eX, &eY, &tCount) == 5) {
        Serial.printf("APPROVE S(%d,%d) E(%d,%d) count=%d\n", sX, sY, eX, eY, tCount);
        sendToApp("LIGHT:GREEN"); 
        scanTargetCount = tCount; 
        scanStartX = sX; scanStartY = sY; 
        scanStepX = (sX == eX) ? 0 : ((eX > sX) ? 1 : -1); 
        scanStepY = (sX == eX) ? ((eY > sY) ? 1 : -1) : 0; 
        currentScanCount = 0; 
        waitingForAppInput = false;
        stopFlag = false;
        for (int i = 0; i < MAX_TOKENS; i++) tempRoundUIDs[i] = "";
        isScanning = true;
      } else {
        Serial.println("APPROVE Parse Error");
      }
    } 
    else if (rx.indexOf("REF:REJECT") != -1) { 
      sendToApp("LIGHT:RED");
      delay(2000); sendToApp("LIGHT:OFF"); 
      currentTurn = (currentTurn == 1) ? 2 : 1; 
      sendToApp("TURN:" + String(currentTurn));
    }
    else if (rx.indexOf("CMD:PASS") != -1 || rx.indexOf("CMD:CHANGE") != -1) { 
      String action = (rx.indexOf("CMD:PASS") != -1) ? "PASS" : "CHANGE"; 
      sendToApp("MSG:P" + String(currentTurn) + "_" + action); delay(500); 
      skipTurnCount++; 
      if (skipTurnCount >= 6) triggerGameOver("PASS_LIMIT");
      else { 
        currentTurn = (currentTurn == 1) ? 2 : 1;
        sendToApp("TURN:" + String(currentTurn)); 
      }
    }
  }
};

class MyServerCallbacks: public BLEServerCallbacks { 
  void onConnect(BLEServer* pServer) { 
    deviceConnected = true; 
    BLEDevice::startAdvertising();
    Serial.println("Mobile Connected!"); 
  } 
  void onDisconnect(BLEServer* pServer) { 
    deviceConnected = false; 
    stopFlag = true;
    isScanning = false;       
    disableDrivers();         
    BLEDevice::startAdvertising(); 
    Serial.println("Mobile Disconnected!"); 
  } 
};


// ==========================================================
// PART 6: SETUP & MAIN LOOP
// ==========================================================
void setup() {
  Serial.begin(115200);
  
  pinMode(RC522_RST, OUTPUT);
  digitalWrite(RC522_RST, LOW);
  delay(500);                      
  digitalWrite(RC522_RST, HIGH);   
  delay(500);

  SPI.begin(8, 12, 11, 10);
  rfid.PCD_Init();
  delay(100);
  
  rfid.PCD_SetAntennaGain(MFRC522::RxGain_38dB);
  byte ver = rfid.PCD_ReadRegister(MFRC522::VersionReg);
  if (ver == 0x00 || ver == 0xFF) { 
    Serial.println("RC522 not found!"); 
    while (1);
  }
  Serial.printf("RC522 OK (0x%02X)\n", ver);

  pinMode(STEP_X, OUTPUT); pinMode(DIR_X, OUTPUT); pinMode(EN_X, OUTPUT);
  pinMode(STEP_Y, OUTPUT); pinMode(DIR_Y, OUTPUT); pinMode(EN_Y, OUTPUT);
  pinMode(LIMIT_X, INPUT_PULLUP);
  pinMode(LIMIT_Y, INPUT_PULLUP);
  disableDrivers();

  BLEDevice::init("A-Math_Hub");   
  pServer = BLEDevice::createServer(); 
  pServer->setCallbacks(new MyServerCallbacks()); 
  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID, 
    BLECharacteristic::PROPERTY_READ | 
    BLECharacteristic::PROPERTY_WRITE | 
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->setCallbacks(new MyCallbacks()); 
  pCharacteristic->addDescriptor(new BLE2902());    
  pService->start();                
  pServer->getAdvertising()->start(); 
  
  Serial.println("Homing Start...");
  enableDrivers(); 
  homeXY(); 
  disableDrivers(); 
  Serial.println("ESP32 Ready!");
}

void loop() {
  if (cmdStartPending) {
    cmdStartPending = false;
    enableDrivers(); 
    homeXY(); 
    disableDrivers();
    Serial.println("Game Start Pending Done");
  }

  if (cmdReturnHomePending) {
    cmdReturnHomePending = false;
    enableDrivers();
    if (!stopFlag) moveFastAxis(STEP_X, DIR_X, curX, 0, CAL_X, 150);
    if (!stopFlag) moveFastAxis(STEP_Y, DIR_Y, curY, Y_MAX, CAL_Y, 150);
    disableDrivers(); 
    Serial.println("Return Home Done");
  }

  if (isScanning && currentScanCount < scanTargetCount && !waitingForAppInput && !stopFlag) { 
    int currX = scanStartX + (currentScanCount * scanStepX);
    int currY = scanStartY + (currentScanCount * scanStepY); 
    int currIdx = (currY * 15) + currX;

    enableDrivers();
    moveFastAxis(STEP_X, DIR_X, curX, currX, CAL_X, 150);        
    moveFastAxis(STEP_Y, DIR_Y, curY, currY, CAL_Y, 150);  
    disableDrivers();
    
    if (stopFlag) { isScanning = false; return; }

    if (boardTokens[currIdx] != "") {
      tokens[currentScanCount] = boardTokens[currIdx];
      tokenScores[currentScanCount] = boardScores[currIdx]; 
      tokenIndexes[currentScanCount] = currIdx;
      tempRoundUIDs[currentScanCount] = "OLD_TILE"; 
      sendToApp("SCAN:UID:OLD|IDX:" + String(currIdx) + "|TOK:" + tokens[currentScanCount]); 
      currentScanCount++;
      delay(300);
    } 
    else {
      Serial.printf("\nScan at (%d,%d)...\n", currX, currY);

      rfid.PCD_Init();
      rfid.PCD_SetAntennaGain(MFRC522::RxGain_38dB);
      delay(200);
      String uidHex = "";
      bool found = false;

      auto tryRead = [&]() {
        if (rfid.PICC_IsNewCardPresent() && rfid.PICC_ReadCardSerial()) {
          uidHex = "";
          for (int i = 0; i < rfid.uid.size; i++) {
            if (rfid.uid.uidByte[i] < 0x10) uidHex += "0";
            uidHex += String(rfid.uid.uidByte[i], HEX);
            if (i < rfid.uid.size - 1) uidHex += " ";
          }
          uidHex.toUpperCase();
          rfid.PICC_HaltA();
          rfid.PCD_StopCrypto1();
          found = true;
          Serial.println("UID: " + uidHex);
        }
      };

      for (int attempt = 0; attempt < 150 && !found && !stopFlag; attempt++) {
        tryRead();
        delay(10);
        yield();
      }

      if (!found && !stopFlag) {
        Serial.println("Reset RF and try again...");
        rfid.PCD_Init();
        rfid.PCD_SetAntennaGain(MFRC522::RxGain_38dB);
        delay(200);
        for (int attempt = 0; attempt < 50 && !found && !stopFlag; attempt++) {
          tryRead();
          delay(10);
          yield();
        }
      }

      if (found) {
        if (isUidAlreadyScanned(uidHex)) {
          Serial.println("Duplicate UID!");
          sendToApp("MSG:DUPLICATE_TILE");
          delay(1000);
          currentScanCount++;
        } else {
          String tok = mapUidToToken(uidHex);
          if (tok != "") {
            int originalScore = getTokenScore(tok);
            tempRoundUIDs[currentScanCount] = uidHex;

            if (tok == "BLANK" || tok == "+/-" || tok == "x/÷") {
              sendToApp("SCAN:UID:" + uidHex + "|IDX:" + String(currIdx) + "|TOK:" + tok);
              tokenScores[currentScanCount] = originalScore;
              tokenIndexes[currentScanCount] = currIdx;
              waitingForAppInput = true;
              Serial.println("Special tile waiting for app choice...");
              while (waitingForAppInput && !stopFlag) {
                delay(10);
                yield();
              }
              if (!stopFlag) currentScanCount++;
            } else {
              tokens[currentScanCount] = tok;
              tokenScores[currentScanCount] = originalScore;
              tokenIndexes[currentScanCount] = currIdx;
              sendToApp("SCAN:UID:" + uidHex + "|IDX:" + String(currIdx) + "|TOK:" + tok);
              Serial.println("Found: [" + tok + "]");
              currentScanCount++;
              delay(800);
            }
          } else {
            Serial.println("UID not in DB: " + uidHex);
            currentScanCount++;
          }
        }
      } else {
        Serial.println("No Tag, skipping...");
        sendToApp("MSG:NO_TAG|IDX:" + String(currIdx));
        tokens[currentScanCount] = "EMPTY";
        tokenIndexes[currentScanCount] = currIdx;
        tokenScores[currentScanCount] = 0;
        currentScanCount++;
      }
    }
  }

   else if (isScanning && currentScanCount == scanTargetCount && !stopFlag) {
    isScanning = false;                                       
    int score = evaluateExpression();
    if (score == -1) {                                        
      Serial.println("Wrong Expression!");
      sendToApp("MSG:WRONG_EQ"); 
      sendToApp("LIGHT:RED"); 
      delay(2000); 
      sendToApp("LIGHT:OFF"); 
    } else {                                                  
      Serial.println("Correct! Score: " + String(score));
      skipTurnCount = 0; 

      for (int i = 0; i < scanTargetCount; i++) {
        if (tempRoundUIDs[i] != "OLD_TILE" && tempRoundUIDs[i] != "") {
          usedUIDs[usedUIDCount] = tempRoundUIDs[i];
          usedUIDCount++;
        }
      }

      for (int i = 0; i < scanTargetCount; i++) {
        isBonusUsed[tokenIndexes[i]] = true;
        boardTokens[tokenIndexes[i]] = tokens[i];            
        boardScores[tokenIndexes[i]] = tokenScores[i];       
      }

      String eqStr = "";
      for (int i = 0; i < scanTargetCount; i++) eqStr += tokens[i];
      String playerStr = (currentTurn == 1) ? "P1" : "P2";
      int totalScoreNow = 0;
      if (currentTurn == 1) { 
        p1TotalScore += score;
        totalScoreNow = p1TotalScore; 
      } else { 
        p2TotalScore += score; 
        totalScoreNow = p2TotalScore;
      }

      sendToApp("HISTORY:" + playerStr + ":" + String(turnCount) + ":" + eqStr + ":" + String(score) + ":" + String(totalScoreNow));
      turnCount++; 
      sendToApp("SCORE:" + String(currentTurn) + ":" + String(totalScoreNow));
      delay(1000);
    }

    currentTurn = (currentTurn == 1) ? 2 : 1;                
    sendToApp("TURN:" + String(currentTurn)); 
    sendToApp("LIGHT:OFF"); 
    cmdReturnHomePending = true;
  }
}