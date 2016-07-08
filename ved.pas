program Ved;
uses
  Sysutils,Crt;

const
  T_WIDTH = 80;
  T_HEIGHT = 43;

type
  linestr = string [T_WIDTH];
  lineptr = ^linestr;

var
  x,y : integer; { cursor coordinates }
  status : string;
  linecount : integer;
  lines : array [1..1000] of lineptr;

{* Render functions *}
procedure RenderText(startln : integer);
begin
  GotoXY(1,startln);
  repeat
    ClrEol;
    Writeln(lines[startln]^);
    Inc(startln);
  until (startln > linecount) or (startln = T_HEIGHT - 1);
end;

procedure RenderLn(lnr : integer);
begin
  GotoXY(1,lnr);
  ClrEol;
  if lnr <= linecount then
    Writeln(lines[lnr]^);
  GotoXY(x,y);
end;

procedure RenderCurLn;
begin
  RenderLn(y);
end;

procedure RenderStatus;
begin
  GotoXY(1,T_HEIGHT);
  TextBackground(White);
  TextColor(Black);
  Write(status);
  ClrEol;
  NormVideo;
end;

procedure RenderCursor;
var
  newX,len : integer;
begin
  { If x is more than line length, goto end of line }
  newX := x;
  len := Length(lines[y]^);
  if x > len then newX := len;
  if len = 0 then newX := 1;
  GotoXY(newX,y);
end;

procedure Render;
begin
  RenderText(1);
  RenderStatus;
  RenderCursor;
end;

procedure RenderDown;
begin
  RenderText(y);
  RenderStatus;
  RenderCursor;
end;

procedure PrintStatus(msg : string);
begin
  status := msg;
  RenderStatus;
end;

procedure AdjustEol;
var
  len : integer;
begin
  len := Length(lines[y]^);
  if x > len then x := len;
  if x = 0 then x := 1;
end;

{* ***************** *}
{* Movement function *}
{* ***************** *}

procedure GoLeft;
begin
  AdjustEol;
  if x <> 1 then Dec(x);
  RenderCursor;
end;

procedure GoRight;
begin
  AdjustEol;
  if x < Length(lines[y]^) then Inc(x);
  RenderCursor;
end;

procedure GoUp;
begin
  if y <> 1 then Dec(y);
  RenderCursor;
end;

procedure GoDown;
begin
  if y <> linecount then Inc(y);
  RenderCursor;
end;

procedure GoFarRight;
begin
  x := Length(lines[y]^);
  RenderCursor;
end;

procedure GoFarLeft;
begin
  x := 1;
  RenderCursor;
end;

function EndOfLine : boolean;
begin
  if x >= Length(lines[y]^) then
    begin
      EndOfLine := True;
    end
  else
    begin
      EndOfLine := False;
    end;
end;

{* ***************************** *}
{* Buffer modification functions *}
{* ***************************** *}

procedure DeleteLn(lnr : integer);
var
  i : integer;
begin
  Dispose(lines[lnr]);
  for i := lnr to linecount do
    lines[i] := lines[i+1];
  Dec(linecount);
end;

procedure InsertLine(lnr : integer; value : linestr);
var
  i : integer;
begin
  Inc(lnr);
  for i := linecount downto lnr do
    lines[i+1] := lines[i];
  Inc(linecount);
  New(lines[lnr]);
  lines[lnr]^ := value;
end;

procedure BreakLn(lnr,index : integer);
var
  len : integer;
begin
  len := Length(lines[lnr]^) - index + 1;
  InsertLine(y,RightStr(lines[lnr]^,len));
  Delete(lines[y]^,index,len);
end;

procedure DeleteChar(lnr, index: integer);
begin
  if Length(lines[lnr]^) <> 0 then
    Delete(lines[lnr]^, index, 1);
end;

procedure InsertChar(ch : char);
begin
  PrintStatus('Inserting character');
  Insert(ch,lines[y]^,x);
  inc(x);
  RenderCurLn;
  GotoXY(x,y);
end;

{ ***************************** }

procedure JumpToNewLn(value : linestr);
begin
  InsertLine(y,value);
  Inc(y);
  x := 1;
  RenderDown;
end;

procedure ReadInsert;
var
  ch : char;
begin
  PrintStatus('[ INSERT ]');
  repeat
    ch := ReadKey();
    case ch of
      #8  : begin                 { Backspace }
              if x > 0 then begin
		Dec(x);
                DeleteChar(y,x);
                RenderCurLn;
  		GotoXY(x,y);
              end;
            end;
      #13 : begin                 { Line feed }
              if EndOfLine then
                begin
                  JumpToNewLn('');
                end
              else
                begin
		  BreakLn(y,x);
                  Inc(y);
                  x := 1;
                  RenderDown;
                end;
              ReadInsert;
              ch := #27; { Exit to cmd mode }
            end;
      #27 : ch := #27;            { ESC }
      else InsertChar(ch);        { Character }
    end;
  until ch = #27;

  if x > 1 then Dec(x);
  RenderCursor;
  PrintStatus('');
end;

procedure LoadFile(filename : string);
var
  filedesc : text;
  i : integer;
begin
  Assign(filedesc,filename);
  Reset(filedesc);

  if (ioresult <> 0) then
    begin
      ClrScr;
      Writeln('File does not exist: ',filename);
      Halt;
    end;

  i := 1;
  while not Eof(filedesc) and (i < 100) do
    begin
      New(lines[i]);
      Readln(filedesc,lines[i]^);
      Inc(i);
    end;

  linecount := i - 1;
  Close(filedesc);
end;

procedure SaveFile(filename : string);
var
  filedesc : text;
  i : integer;
begin
  Assign(filedesc, filename);
  Erase(filedesc);
  Rewrite(filedesc);
  for i := 1 to linecount do Writeln(filedesc,lines[i]^);
  Close(filedesc);
end;

procedure ShowHelp(prgname : string);
begin
  Writeln('Usage: ', prgname,' filename');
end;

{ START OF PROGRAM }
var
  ch : char;
begin
  if ParamCount < 1 then
    begin
      ShowHelp(ParamStr(0));
      Halt;
    end;

  x := 1;
  y := 1;
  status := 'File loaded!';

  ClrScr;
  LoadFile(ParamStr(1));
  Render;

  repeat
    ch := ReadKey;
    case ch of
      #104 : GoLeft;         { h }
      #108 : GoRight;        { l }
      #106 : GoDown;         { j }
      #107 : GoUp;           { k }
      #111 : begin           { o }
               JumpToNewLn('');
               ReadInsert;
               ch := #0;
             end;
      #120 : begin           { x }
  	       AdjustEol;
	       DeleteChar(y,x);
               RenderCurLn;
               AdjustEol;
               RenderCursor;
	     end;
      #105 : begin           { i }
               AdjustEol;
               ReadInsert;
               ch := #0;
             end;
      #73 : begin           { I }
               GoFarLeft;
               ReadInsert;
               ch := #0;
             end;
      #97  : begin           { a }
               AdjustEol;
               Inc(x);
               ReadInsert;
               ch := #0;
             end;
      #65  : begin           { A }
               GoFarRight;
               Inc(x);
               ReadInsert;
               ch := #0;
             end;
      #74  : begin           { J }
               if y < linecount then
                 begin
                   Insert(lines[y+1]^,lines[y]^,Length(lines[y]^) + 1);
                   DeleteLn(y+1);
                   RenderLn(y+1);
                   RenderDown;
                 end;
             end;
      #0   : begin           { NULL }
               ch := ReadKey;
               case ch of
                 #75 : GoLeft;
                 #77 : GoRight;
               end;
             end;
      #27  : PrintStatus('ESC');
    end;
  until ch = #27;

  SaveFile(ParamStr(1));
end.
