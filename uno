#include <GSM.h>
#include <GSM3Serial1.h>
#include <PhoneBook.h>
#include <SoftwareSerial.h>
SoftwareSerial SIM900(0, 1);
//GSM gsmAccess(true);
GSMVoiceCall vcs(false);
GSM_SMS sms(false);
GSMScanner scannerNetworks;

PhoneBook pb;
int signalQuality;

int x = 0, y = 0;//这里还要看看是后面哪里的

char number[20];//输入最长字符长度
char name[20];

#define NAME_OR_NUMBER() (name[0] == 0 ? (number[0] == 0 ? "Unknown" : number) : name)//这应该是来电显示的。

int missed = 0;//miss的电话数量

GSM3_voiceCall_st prevVoiceCallStatus;// 新类对象

enum Mode { NOMODE, TEXTALERT, MISSEDCALLALERT,LOCKED, HOME, DIAL, PHONEBOOK, EDITENTRY, EDITTEXT, MENU, MISSEDCALLS, RECEIVEDCALLS, DIALEDCALLS, TEXTS};

Mode mode = LOCKED, prevmode, backmode = mode, interruptedmode = mode;

boolean initmode, back;

struct menuentry_t {
  char *name;
  Mode mode;//Menu Entry 的结构体
  void (*f)();
};

menuentry_t mainmenu[] = {
  { "Missed calls", MISSEDCALLS, 0 },//初始化显示一些标量的初值
  { "Received calls", RECEIVEDCALLS, 0 },
  { "Dialed calls", DIALEDCALLS, 0 },
};

menuentry_t phoneBookEntryMenu[] = {
  { "Call", PHONEBOOK, callPhoneBookEntry },
  { "Text", EDITTEXT, initTextFromPhoneBookEntry },
  { "Add entry", EDITENTRY, initEditEntry },
  { "Edit", EDITENTRY, initEditEntryFromPhoneBookEntry },
  { "Delete", PHONEBOOK, deletePhoneBookEntry }
};

menuentry_t callLogEntryMenu[] = {
  { "Call", MISSEDCALLS, callPhoneBookEntry },
  { "Save number", EDITENTRY, initEditEntryFromCallLogEntry },
  { "Delete", MISSEDCALLS, deleteCallLogEntry }
};

menuentry_t *menu;

int menuLength;
int menuLine;

const int NUMPHONEBOOKLINES = 5;
int phoneBookIndices[NUMPHONEBOOKLINES];
char phoneBookNames[NUMPHONEBOOKLINES][ENTRY_SIZE];
char phoneBookNumbers[NUMPHONEBOOKLINES][ENTRY_SIZE];
boolean phoneBookHasDateTime[NUMPHONEBOOKLINES];
DateTime phoneBookDateTimes[NUMPHONEBOOKLINES];
int phoneBookSize;
int phoneBookIndexStart; // inclusive
int phoneBookIndexEnd; // exclusive
int phoneBookLine;
int phoneBookPage;

long phoneBookCache[256];
int phoneBookCacheSize;

//输入buffer测试
#include "SPI.h"
#include "Adafruit_GFX.h"
#include "Adafruit_ILI9340.h"
#include <Keypad.h>

#if defined(__SAM3X8E__)
    #undef __FlashStringHelper::F(string_literal)
    #define F(string_literal) string_literal
#endif

#define _sclk 13
#define _rst 12
#define _mosi 11
#define _cs 10
#define _dc 9

Adafruit_ILI9340 tft = Adafruit_ILI9340(_cs, _dc, _rst);



int redLED = A5;
int greenLED =A4;
int leftButton = A3;
int rightButton =A0;
int upButton =A1;
int downButton = A2;

//initial value of leds and buttons.
int a0 = 0;
int a1 = 0;
int a2 = 0;
int a3 = 0;
int a4 = 0;
int a5 = 0;


const byte ROWS = 4; 
const byte COLS = 3; 
char keys[ROWS][COLS] = {
  {'1','2','3'},
  {'4','5','6'},
  {'7','8','9'},
  {'*','0','#'},
};
byte rowPins[ROWS] = {2, 3, 4, 5}; 
byte colPins[COLS] = {6, 7, 8}; 

Keypad keypad = Keypad( makeKeymap(keys), rowPins, colPins, ROWS, COLS );


char number[20];//输入最长字符长度
char name[20];




#define SCREEN_WIDTH 14
#define ENTRY_SIZE 20

int entryIndex;//输入时必要的
char entryName[ENTRY_SIZE], entryNumber[ENTRY_SIZE];
enum EntryField { NAME, NUMBER };
EntryField entryField;

char text[161];
int textline;


char uppercase[10][10] = { 
  { ' ', '0', 0 },
  { ',', '.', '?', '!','1', 0 },
  { 'A', 'B', 'C', '2', 0 },
  { 'D', 'E', 'F', '3', 0 },
  { 'G', 'H', 'I', '4', 0 },
  { 'J', 'K', 'L', '5', 0 },
  { 'M', 'N', 'O', '6', 0 },
  { 'P', 'Q', 'R', 'S', '7', 0 },
  { 'T', 'U', 'V', '8', 0 },
  { 'W', 'X', 'Y', 'Z', '9', 0 },
};

char lowercase[10][10] = { 
  { ' ', '0', 0 },
  { ',', '.', '?', '!','1', 0 },
  { 'a', 'b', 'c', '2', 0 },
  { 'd', 'e', 'f', '3', 0 },
  { 'g', 'h', 'i', '4', 0 },
  { 'j', 'k', 'l', '5', 0 },
  { 'm', 'n', 'o', '6', 0 },
  { 'p', 'q', 'r', 's', '7', 0 },
  { 't', 'u', 'v', '8', 0 },
  { 'w', 'x', 'y', 'z', '9', 0 },
};

char (*letters)[10];

char lastKey;
int lastKeyIndex;
unsigned long lastKeyPressTime;
boolean shiftNextKey;

boolean unlocking, blank;
//-----------------------------------------------------------------
//
//initialization 到此结束
//
//-----------------------------------------------------------------
void setup() {
  Serial.begin(19200);
  while (!Serial);
  pinMode(leftButton, INPUT);
  pinMode(rightButton, INPUT);
  pinMode(upButton, INPUT);
  pinMode(downButton, INPUT);
  
  SIM900.begin(19200);
  delay(1000);
  
  Serial.println("Test!"); 
 
  tft.begin();
  tft.setCursor(0,0);
  delay(2000);
  tft.println("connecting...");
  Serial.print("Begin");
  
  
  tft.println("caching...");
  cachePhoneBook();
  tft.println("done.");
}
//-------------------------------------------------------------------
//
//setup(void)到此结束
//
//-------------------------------------------------------------------
void loop(){
  tft.fillScreen(ILI9340_BLACK);
  char key = keypad.getKey();
  a0 = analogRead(A0);
  a1 = analogRead(A1);
  a2 = analogRead(A2);
  a3 = analogRead(A3);
//------------------------------
  

//
  tft.setTextColor(ILI9340_BLACK);
  
  GSM3_voiceCall_st voiceCallStatus = vcs.getvoiceCallStatus();
  switch (voiceCallStatus) {
    case IDLE_CALL:
      if (mode != MISSEDCALLALERT && prevmode != MISSEDCALLALERT && mode != LOCKED && mode != TEXTALERT > 0) {//mode:: 1
        interruptedmode = mode;
        mode = MISSEDCALLALERT;
      }
    
      if (mode != TEXTALERT && prevmode != TEXTALERT && mode != LOCKED && mode != MISSEDCALLALERT && millis() - lastSMSCheckTime > 10000) {//mode::2
        lastSMSCheckTime = millis();
        sms.available();
        while (!sms.ready());
        if (sms.ready() == 1) {
          interruptedmode = mode;
          mode = TEXTALERT;
        }
      }
//-- 这里几个参数要在看看
      if ((mode == HOME || (mode == LOCKED && !unlocking)) && millis() - lastSignalQualityCheckTime > 30000) {//mode :: 3
        signalQuality = scannerNetworks.getSignalStrength().toInt();
        lastSignalQualityCheckTime = millis();
      }

      initmode = (mode != prevmode) && !back;
      back = false;
      prevmode = mode;
      
      if (mode == HOME || (mode == LOCKED && unlocking)) {        
        tft.setTextColor(ILI9340_WHITE, ILI9340_BLACK);
        tft.print("     ");

//--------------------------------
//信号管理
tft.setTextColor(ILI9340_BLACK);
if (signalQuality != 99)
   for (int i = 1; i <= (signalQuality + 4) / 6; i++)
   tft.drawFastVLine(i, 7 - i, i, WHITE);
//---------------------------------
    }
}

//-------------------------------------------------------------
//-------------------------------------------------------------
//--
if (mode == MISSEDCALLALERT) {     //mode::4: MissedCallAlert
        tft.print("Missed: ");
        tft.println(missed);
        tft.println("Last from: ");
        tft.println(NAME_OR_NUMBER());
        softKeys("close", "call");
//-------------------------------------------------------------
//--
        if (a3 > 500) { //Left key
          missed = 0;
          mode = interruptedmode;
        }
        if (a0 > 500) {// Right key
          missed = 0;
          mode = interruptedmode;
          vcs.voiceCall(number);
        }
//---------------------------------------------------------------
//--
      } else if (mode == TEXTALERT) // mode::5:  TextAlert
              if (initmode) {
          sms.remoteNumber(number, sizeof(number));
          name[0] = 0;
          int i = 0;
          for (; i < sizeof(text) - 1; i++) {
            int c = sms.read();
            if (!c) break;
            text[i] = c;
          }
          text[i] = 0;
          textline = 0;
          sms.flush(); // XXX: should save to read message store, not delete
        }
//----------------------------------------------------------------------
        if (name[0] == 0) phoneNumberToName(number, name, sizeof(name) / sizeof(name[0]));
        
        screen.print(NAME_OR_NUMBER());
        screen.println(":");
        
        for (int i = textline * SCREEN_WIDTH; i < textline * SCREEN_WIDTH + 56; i++) {
          if (!text[i]) break;
          screen.print(text[i]);
        }
        softKeys("close", "reply");
        
        if (a3 > 500) mode = interruptedmode;//left
        if (a0 > 500) {    // right
          text[0] = 0;
          mode = EDITTEXT;
          fromalert = true;
        }
        if (a1 > 500) { //up
          if (textline > 0) textline--;
        }
        if (a2 > 500) { //down
          if (strlen(text) > (textline * SCREEN_WIDTH + 56)) textline++;
        }
//-----------------------------------------
      } else if (mode == LOCKED) { //mode::6: Locked
        if (initmode) {
          unlocking = false;//锁屏幕和解锁
          blank = false;
        }
//-------------------------------------------
if (unlocking) {
          softKeys("Unlock");
          if (a3 > 500) { mode = HOME; unlocking = false; }
if (a2 > 500) { lastKeyPressTime = millis(); }
if (millis() - lastKeyPressTime > 3000) unlocking = false;
} else {
if (key) {
            unlocking = true;
            lastKeyPressTime = millis();
          }
}
} else if (mode == HOME) {
        softKeys("lock", "menu");		//mode:: 7: home
        
        if ((key >= '0' && key <= '9') || key == '#') {
          lastKeyPressTime = millis();
          number[0] = key; number[1] = 0;
          mode = DIAL;//切换到拨号
        } else if (a3 > 500) {
          mode = LOCKED;//切换到锁屏
        } else if (a0 >500) {
          mode = MENU;//切换到菜单
          menu = mainmenu;
          menuLength = sizeof(mainmenu) / sizeof(mainmenu[0]);
          backmode = HOME;
        } else if (a2 >0) {
          mode = PHONEBOOK;
        }
      } else if (mode == DIAL) {		//mode:: 8: dial
        numberInput(key, number, sizeof(number));
        softKeys("back", "call");
        
        if (a3 > 0) {//左键回主页
          mode = HOME;
        } else if (a0 >500) {//右键打通电话
          if (strlen(number) > 0) {
            mode = HOME; // for after call ends
            name[0] = 0;
            vcs.voiceCall(number);
            while (!vcs.ready());
          }
        }//结束mode=DIAL
      } else if (mode == PHONEBOOK || mode == MISSEDCALLS || mode == RECEIVEDCALLS || mode == DIALEDCALLS) {//mode::9:其他模式
        if (initmode) {
          if (mode == PHONEBOOK) pb.selectPhoneBook(PHONEBOOK_SIM);
          if (mode == MISSEDCALLS) pb.selectPhoneBook(PHONEBOOK_MISSEDCALLS);
          if (mode == RECEIVEDCALLS) pb.selectPhoneBook(PHONEBOOK_RECEIVEDCALLS);
          if (mode == DIALEDCALLS) pb.selectPhoneBook(PHONEBOOK_DIALEDCALLS);
          while (!pb.ready());
          delay(300); // otherwise the module gives an error on pb.queryPhoneBook()//这两句要再看看
          pb.queryPhoneBook();
          while (!pb.ready());
          phoneBookSize = pb.getPhoneBookSize();
          phoneBookPage = 0;
          phoneBookLine = 0;
          phoneBookIndexStart = 1;
          phoneBookIndexEnd = loadphoneBookNamesForwards(phoneBookIndexStart, NUMPHONEBOOKLINES);
          lastKeyPressTime = millis();
        }

        for (int i = 0; i < NUMPHONEBOOKLINES; i++) {
          if (i == phoneBookLine) tft.setTextColor(ILI9340_WHITE, ILI9340_BLACK);
          else tft.setTextColor(ILI9340_BLACK);
if (strlen(phoneBookNames[i]) > 0) {
            for (int j = 0; j < SCREEN_WIDTH && phoneBookNames[i][j]; j++) screen.print(phoneBookNames[i][j]);
            if (strlen(phoneBookNames[i]) < SCREEN_WIDTH) screen.println();
          } else if (strlen(phoneBookNumbers[i]) > 0) {
            screen.print(phoneBookNumbers[i]);
            if (strlen(phoneBookNumbers[i]) < SCREEN_WIDTH) screen.println();
          } else if (phoneBookIndices[i] != 0) {
            screen.println("Unknown");
}
        }
        softKeys("back", "okay");
        
        if (a3 > 500) mode = HOME;
else if (a0>500) {
          backmode = mode;
          if (mode == PHONEBOOK) {
            mode = MENU;
            menu = phoneBookEntryMenu;
            menuLength = sizeof(phoneBookEntryMenu) / sizeof(phoneBookEntryMenu[0]);
          } else {
            mode = MENU;
            menu = callLogEntryMenu;
            menuLength = sizeof(callLogEntryMenu) / sizeof(callLogEntryMenu[0]);
          }
        } else if (a2>500) {
          if (phoneBookPage * NUMPHONEBOOKLINES + phoneBookLine + 1 < pb.getPhoneBookUsed()) {
            phoneBookLine++;
            if (phoneBookLine == NUMPHONEBOOKLINES) {
              phoneBookPage++;
              phoneBookIndexStart = phoneBookIndexEnd;
              phoneBookIndexEnd = loadphoneBookNamesForwards(phoneBookIndexStart, NUMPHONEBOOKLINES);
              phoneBookLine = 0;
            }
            lastKeyPressTime = millis();
          }
        } else if (a1>500) {
          if (phoneBookLine > 0 || phoneBookPage > 0) {
            phoneBookLine--;
            if (phoneBookLine == -1) {
              phoneBookPage--;
              phoneBookIndexEnd = phoneBookIndexStart;
              phoneBookIndexStart = loadphoneBookNamesBackwards(phoneBookIndexEnd, NUMPHONEBOOKLINES);
              phoneBookLine = NUMPHONEBOOKLINES - 1;
            }
            lastKeyPressTime = millis();
          }
        }
      } else if (mode == EDITENTRY) {//这个mode要再看看要不要
        if (initmode) entryField = NAME;
        
        tft.println("Name:");
        if (entryField != NAME) tft.println(entryName);
        else textInput(key, entryName, sizeof(entryName));
        
        tft.println("Number:");
        if (entryField != NUMBER) tft.println(entryNumber);
        else numberInput(key, entryNumber, sizeof(entryNumber));
                
        softKeys("cancel", "save");

        if (entryField == NAME) {
          if (a2>500) entryField = NUMBER;
        }
        
        if (entryField == NUMBER) {//这里要把U和D键换成别的键试试
          if (a1 >500) entryField = NAME;
        }
        
        if (a3>500) {
          mode = backmode;
          back = true;
        }
        if (a0>500) {
          savePhoneBookEntry(entryIndex, entryName, entryNumber);
          mode = PHONEBOOK;
        }
      } else if (mode == EDITTEXT) {//编辑短信模式
        textInput(key, text, sizeof(text));
        softKeys("cancel", "send");
        
        if (a3>500) {
          mode = (fromalert ? HOME : PHONEBOOK);//这里应该直接跳回主页
          back = true;
        } 
        if (a0>500) {
          sendText(number, text);//发信函数（方法）， 应该返回一个值， 同时能显示是否成功。
          mode = HOME;
          back = true;
        }
      } else if (mode == MENU) {
        if (initmode) menuLine = 0;//菜单模式（需要再看看怎么弄）

        for (int i = 0; i < menuLength; i++) {
          if (menuLine == i) tft.setTextColor(ILI9340_WHITE, ILI9340_BLACK);
          else tft.setTextColor(BLACK);
          tft.print(menu[i].name);
          if (strlen(menu[i].name) % SCREEN_WIDTH != 0) tft.println();
        }
        
        softKeys("back", "okay");
        
        if (a1>500) {
          if (menuLine > 0) menuLine--;
        } else if (a2>500) {
          if (menuLine < menuLength - 1) menuLine++;
        } else if (a0>500) {
          mode = menu[menuLine].mode;
          if (menu[menuLine].f) menu[menuLine].f();
        } else if (a3>500) {
          mode = backmode;
          back = true;
        }
      } else if (mode == TEXTS) {//
        softKeys("back");
        if (a3>500) mode = HOME;
}
      break;
case CALLING:// 第二个case
      tft.println("Calling:");
      tft.print(NAME_OR_NUMBER());
      softKeys("end");//
      if (a3>500) {
        vcs.hangCall();// 这里hang表示挂机
        while (!vcs.ready());
      }
      break;
    case RECEIVINGCALL://第三个case
      if (prevVoiceCallStatus != RECEIVINGCALL) {
        missed++;
        name[0] = 0;
        number[0] = 0;
}
if (strlen(number) == 0) vcs.retrieveCallingNumber(number, sizeof(number));
      if (strlen(number) > 0 && name[0] == 0) {
        phoneNumberToName(number, name, sizeof(name) / sizeof(name[0]));
      }
    analogWrite(greenLED, 0);
    analogWrite(redLED, 1023);
tft.println("incoming:");
      tft.println(NAME_OR_NUMBER());//
      softKeys("end", "answer");
      if (a3>500) {
       analogWrite(greenLED, 0);
       analogWrite(redLED, 0);
        missed--;
        vcs.hangCall();
        while (!vcs.ready());
      }
      if (a0>500) {
      analogWrite(greenLED, 1023);
      analogWrite(redLED, 0);
        missed--;
        vcs.answerCall();
        while (!vcs.ready());
      }
      break;
case TALKING://第四个case
 analogWrite(greenLED, 1023);
 analogWrite(redLED, 0);
      tft.println("Connected:");
      tft.println(NAME_OR_NUMBER());
      softKeys("end");
if (a3 >500) {
      analogWrite(greenLED, 0);
      analogWrite(redLED, 0);
        vcs.hangCall();
        while (!vcs.ready());
      }
      break;
  }
prevVoiceCallStatus = voiceCallStatus;
}

11. Handler for program above
boolean checkForCommandReady(GSM3ShieldV1BaseProvider &provider, int timeout)
{
  unsigned long commandStartTime = millis();
  
  while (millis() - commandStartTime < timeout) {
    if (provider.ready()) return true;
  }
  
  return false;
}

void initEditEntry()
{
  entryIndex = 0;
  entryName[0] = 0;
  entryNumber[0] = 0;
}

void initEditEntryFromCallLogEntry()
{
  entryIndex = 0;
  strcpy(entryName, phoneBookNames[phoneBookLine]);
  strcpy(entryNumber, phoneBookNumbers[phoneBookLine]);
}

void initEditEntryFromPhoneBookEntry()
{
  entryIndex = phoneBookIndices[phoneBookLine];
  strcpy(entryName, phoneBookNames[phoneBookLine]);
  strcpy(entryNumber, phoneBookNumbers[phoneBookLine]);
}

void initTextFromPhoneBookEntry() {
  strcpy(number, phoneBookNumbers[phoneBookLine]);
  text[0] = 0;
  fromalert = false;
}

void sendText(char *number, char *text)
{
  sms.beginSMS(number);
  for (; *text; text++) sms.write(*text);
  sms.endSMS();
  
  while (!sms.ready());
}

void callPhoneBookEntry() {
  vcs.voiceCall(phoneBookNumbers[phoneBookLine]);
  while (!vcs.ready());
  strcpy(number, phoneBookNumbers[phoneBookLine]);
  strcpy(name, phoneBookNames[phoneBookLine]);
}

void deletePhoneBookEntry() {
  pb.deletePhoneBookEntry(phoneBookIndices[phoneBookLine]);
  phoneBookCache[phoneBookIndices[phoneBookLine]] = 0;
}

void deleteCallLogEntry() {
  pb.deletePhoneBookEntry(phoneBookIndices[phoneBookLine]);
}

boolean savePhoneBookEntry(int index, char *name, char *number) {
  pb.selectPhoneBook(PHONEBOOK_SIM);
  while (!pb.ready());
  delay(300); // otherwise the module may give an error when accessing the phonebook.
  if (index == 0) {
    // search for an possible empty phone book entry by looking for a cached hash of 0
    for (int i = 1; i < phoneBookCacheSize; i++) {
      if (!phoneBookCache[i]) {
        pb.readPhoneBookEntry(i);
        while (!pb.ready());
        
        // if the entry is really empty, save the new entry there
        if (!pb.gotNumber) {
          pb.writePhoneBookEntry(i, number, name);
          while (!pb.ready());
          phoneBookCache[i] = hashPhoneNumber(number);
          break;
        }
      }
    }
  } else {
    pb.writePhoneBookEntry(index, number, name);
    while (!pb.ready());
    if (pb.ready() == 1) phoneBookCache[index] = hashPhoneNumber(number);
  }
  
  return true;
}

void cachePhoneBook()
{
  int type;
  
  pb.queryPhoneBook();
  while (!pb.ready());
  type = pb.getPhoneBookType();
  
  if (type != PHONEBOOK_SIM) {
    pb.selectPhoneBook(PHONEBOOK_SIM);
    while (!pb.ready());
    delay(300);
    pb.queryPhoneBook();
    while (!pb.ready());
  }
  
  // the phone book entries start at 1, so the size of the cache is one more than the size of the phone book.  
  phoneBookCacheSize = min(pb.getPhoneBookSize() + 1, sizeof(phoneBookCache) / sizeof(phoneBookCache[0]));
  for (int i = 1; i < phoneBookCacheSize; i++) {
    pb.readPhoneBookEntry(i);
    while (!pb.ready());
    if (pb.gotNumber) {
      phoneBookCache[i] = hashPhoneNumber(pb.number);
    }
  }
  
  if (type != PHONEBOOK_SIM) {
    pb.selectPhoneBook(type);
    while (!pb.ready());
  }
}

long hashPhoneNumber(char *s)
{
  long l = 0;
  boolean firstDigit = true;
  for (; *s; s++) {
    if ((*s) >= '0' && (*s) <= '9') {
      if (firstDigit) {
        firstDigit = false;
        if (*s == '1') continue; // skip U.S. country code
      }
      l = l * 10 + (*s) - '0';
    }
  }
  return l;
}

// return true on success, false on failure.
boolean phoneNumberToName(char *number, char *name, int namelen)
{
  if (number[0] == 0) return false;
  
  long l = hashPhoneNumber(number);
  
  for (int i = 1; i < 256; i++) {
    if (l == phoneBookCache[i]) {
      boolean success = false;
      int type;
      
      pb.queryPhoneBook();
      while (!pb.ready());
      type = pb.getPhoneBookType();
      
      if (type != PHONEBOOK_SIM) {
        pb.selectPhoneBook(PHONEBOOK_SIM);
        while (!pb.ready());
        delay(300);
      }
      
      pb.readPhoneBookEntry(i);
      if (checkForCommandReady(pb, 500) && pb.gotNumber) {
        strncpy(name, pb.name, namelen);
        name[namelen - 1] = 0;
        success = true;
      }
      
      if (type != PHONEBOOK_SIM) {
        pb.selectPhoneBook(type);
        while (!pb.ready());
        delay(300);
      }
      
      return success;
    }
  }
  
  return false;
}

int loadphoneBookNamesForwards(int startingIndex, int n)//这个功能应该没有吧
{
  int i = 0;
  
  if (pb.getPhoneBookUsed() > 0) {
    for (; startingIndex <= phoneBookSize; startingIndex++) {
      pb.readPhoneBookEntry(startingIndex);
      while (!pb.ready());
      if (pb.gotNumber) {
        phoneBookIndices[i] = startingIndex;
        strncpy(phoneBookNames[i], pb.name, ENTRY_SIZE);
        phoneBookNames[i][ENTRY_SIZE - 1] = 0;
        strncpy(phoneBookNumbers[i], pb.number, ENTRY_SIZE);
        phoneBookNumbers[i][ENTRY_SIZE - 1] = 0;
        phoneBookHasDateTime[i] = pb.gotTime;
        if (pb.gotTime) memcpy(&phoneBookDateTimes[i], &pb.datetime, sizeof(DateTime));
        if (pb.getPhoneBookType() != PHONEBOOK_SIM) {
          phoneBookNames[i][0] = 0; // the names in the call logs are never accurate (but sometimes present)
          phoneNumberToName(phoneBookNumbers[i], phoneBookNames[i], ENTRY_SIZE); // reuses / overwrites pb
        }
        if (++i == n) break; // found a full page of entries
        if (phoneBookPage * NUMPHONEBOOKLINES + i == pb.getPhoneBookUsed()) break; // hit end of the phonebook
      }
    }
  }
  
  for (; i < n; i++) {
    phoneBookIndices[i] = 0;
    phoneBookNames[i][0] = 0;
    phoneBookNumbers[i][0] = 0;
    phoneBookHasDateTime[i] = false;
  }
  
  return startingIndex + 1;
}

int loadphoneBookNamesBackwards(int endingIndex, int n)
{
  int i = n - 1;
  for (endingIndex--; endingIndex >= 0; endingIndex--) {
    pb.readPhoneBookEntry(endingIndex);
    while (!pb.ready());
    if (pb.gotNumber) {
      phoneBookIndices[i] = endingIndex;
      strncpy(phoneBookNames[i], pb.name, ENTRY_SIZE);
      phoneBookNames[i][ENTRY_SIZE - 1] = 0;
      strncpy(phoneBookNumbers[i], pb.number, ENTRY_SIZE);
      phoneBookNumbers[i][ENTRY_SIZE - 1] = 0;
      phoneBookHasDateTime[i] = pb.gotTime;
      if (pb.gotTime) memcpy(&phoneBookDateTimes[i], &pb.datetime, sizeof(DateTime));
      if (pb.getPhoneBookType() != PHONEBOOK_SIM) {
        phoneBookNames[i][0] = 0; // the names in the call logs are never accurate (but sometimes present)
        phoneNumberToName(phoneBookNumbers[i], phoneBookNames[i], ENTRY_SIZE); // reuses / overwrites pb
      }
      if (--i == -1) break; // found four entries
    }
  }
  for (; i >= 0; i--) {
    phoneBookIndices[i] = 0;
    phoneBookNames[i][0] = 0;
    phoneBookNumbers[i][0] = 0;
    phoneBookHasDateTime[i] = false;
  }
  return endingIndex;
}

void numberInput(char key, char *buf, int len) //数字输入
{
  int i = strlen(buf);
  
  if (i > 0 && (buf[i - 1] == '*' || buf[i - 1] == '#' ) && millis() - lastKeyPressTime <= 

1000) {
    for (int j = 0; j < strlen(buf) - 1; j++) tft.print(buf[j]);
    tft.setTextColor(ILI9340_WHITE, ILI9340_BLACK);
    tft.print(buf[strlen(buf) - 1]);
    tft.setTextColor(ILI9340_BLACK);
  } else {
    tft.print(buf);
    tft.setTextColor(ILI9340_WHITE, ILI9340_BLACK);
    tft.print(" ");
    tft.setTextColor(ILI9340_BLACK);
  }
  
  if (key >= '0' && key <= '9') {
    if (i < len - 1) { buf[i] = key; buf[i + 1] = 0; }
  }
  if (key == '*') {
    if (i > 0) { buf[i - 1] = 0; }
  }
  if (key == '#') {
    if (i > 0 && (buf[i - 1] == '*' || buf[i - 1] == '#' ) && millis() - lastKeyPressTime <= 1000) {
      lastKeyPressTime = millis();
      if (buf[i - 1] == '#') buf[i - 1] = '*';
    } else {
      if (i < len - 1) { buf[i] = '#'; buf[i + 1] = 0; lastKeyPressTime = millis(); }
    }
  }
}

void textInput(char key, char *buf, int len)
{
  if (millis() - lastKeyPressTime > 1000) {
    tft.print(buf);
    tft.setTextColor(ILI9340_WHITE, ILI9340_BLACK);
    tft.print(" ");
    tft.setTextColor(ILI9340_BLACK);
  } else {
    for (int i = 0; i < strlen(buf) - 1; i++) tft.print(buf[i]);
    tft.setTextColor(ILI9340_WHITE, ILI9340_BLACK);
    tft.print(buf[strlen(buf) - 1]);
    tft.setTextColor(ILI9340_BLACK);
  }
  tft.println();
  
  if (key >= '0' && key <= '9') {
    if (millis() - lastKeyPressTime > 1000 || key - '0' != lastKey) {
      // append new letter
      lastKeyIndex = 0;
      lastKey = key - '0';
      int i = strlen(buf);
      
      if (i == 0) letters = uppercase;
      else {
        letters = lowercase;
        }
      }
      int i = strlen(buf);
      if (i < len - 1) { 
       buf[i] = letters[lastKey][lastKeyIndex]; buf[i + 1] = 0;
       }else {
      lastKeyIndex++;
      if (letters[lastKey][lastKeyIndex] == 0) lastKeyIndex = 0; // wrap around
      int i = strlen(buf);
      if (i > 0) { buf[i - 1] = letters[lastKey][lastKeyIndex]; }
    }
      
      if (shiftNextKey) {
        if (letters == uppercase) letters = lowercase;
        else letters = uppercase;
        
        shiftNextKey = false;
      }
      

    lastKeyPressTime = millis();
  }
  if (key == '*') {
    int i = strlen(buf);
    if (i > 0) { buf[i - 1] = 0; }
    lastKeyPressTime = 0;
    shiftNextKey = false;
  }
  if (key == '#') shiftNextKey = true;
}
void softKeys(char *left)
{
  softKeys(left, "");
}
void softKeys(char *left, char *right)
{
  screen.setCursor(0, 40);
  screen.setTextColor(WHITE, BLACK);
  screen.print(left);
  screen.setTextColor(BLACK);
  for (int i = 0; i < SCREEN_WIDTH - strlen(left) - strlen(right); i++) screen.print(" ");
  screen.setTextColor(WHITE, BLACK);
  screen.print(right);
  screen.display();
}
