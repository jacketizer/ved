program Ved (Input, Output);
uses
  Crt;

const
  T_WIDTH = 80;
  T_HEIGHT = 24;
  MAX_LINES = 512;

type
  linestr = string [T_WIDTH];
  lineptr = ^linestr;

var
  x, y : integer; { cursor coordinates }
  offset : integer;
  status : string [70];
  linecount : integer;
  lines : array [1..MAX_LINES] of lineptr;
  cmd : string [10];

{ Uncomment this function for TP 3
function ReadKey : char;
var
  ch : char;
begin
  repeat Read(Kbd, ch) until ch <> #0;
  ReadKey := ch;
end;
}

{
  Render functions
}
procedure RenderText(startln : integer);
var
  screenln : integer;
begin
  screenln := startln - offset;
  GotoXY(1, screenln);
  repeat
    ClrEol;
    Writeln(lines[startln]^);
    startln := Succ(startln);
    screenln := Succ(screenln);
  until (startln > linecount) or
        (screenln > T_HEIGHT - 1);
end;

procedure RenderLn(lnr : integer);
begin
  GotoXY(1, lnr - offset);
  ClrEol;
  Writeln(lines[lnr]^);
  GotoXY(x, y - offset);
end;

procedure RenderCurLn;
begin
  RenderLn(y);
end;

procedure RenderStatus;
var
  percent : integer;
  percentstr : string [4];
begin
  GotoXY(1, T_HEIGHT);
  TextBackground(White);
  TextColor(Black);
  ClrEol;

  if Length(cmd) <> 0 then
    begin
      Write(':', cmd);
    end
  else
    begin
      Write(status);
    end;
 
  if offset = 0 then
    begin
      percentstr := 'Top';
    end
  else
    begin
      percent := Trunc(((offset + T_HEIGHT) / linecount) * 100);
      Str(percent, percentstr);
      percentstr := percentstr + '%';
    end;

  GotoXY(T_WIDTH - Length(percentstr) - 1, T_HEIGHT);
  Write(percentstr); 
  NormVideo;
end;

procedure RenderCursor;
var
  newx, len : integer;
begin
  { If x is more than line length, goto end of line }
  newx := x;
  len := Length(lines[y]^);
  if x > len then newx := len;
  if len = 0 then newx := 1;
  GotoXY(newx, y - offset);
end;

procedure Render;
begin
  RenderText(offset + 1); { Render all }
  RenderStatus;
  RenderCursor;
end;

procedure RenderDown;
begin
  RenderText(y); { Render from current row down }
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

{
  Movement functions
}
procedure GoLeft;
begin
  AdjustEol;
  if x <> 1 then x := Pred(x);
  RenderCursor;
end;

procedure GoRight;
begin
  AdjustEol;
  if x < Length(lines[y]^) then x := Succ(x);
  RenderCursor;
end;

procedure GoUp;
begin
  if y <> 1 then
    begin
      y := Pred(y);
      if (offset > 0) and
         (y - offset = 0) then
        begin
          offset := Pred(offset);
          Render;
        end;
      RenderCursor;
    end
end;

procedure GoDown;
begin
  if y < linecount then
    begin
      y := Succ(y);
      if (y - offset) > T_HEIGHT - 1 then
        begin
          offset := Succ(offset);
	  Render;
        end;
      RenderCursor;
    end;
end;

procedure GoToBottom;
begin
  y := linecount;
  if linecount > T_HEIGHT - 1 then
    begin
      offset := linecount - T_HEIGHT + 1;
    end;
  Render;
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

{
  Buffer modification functions
}
procedure DeleteLn(lnr : integer);
var
  i : integer;
begin
  Dispose(lines[lnr]);
  for i := lnr to linecount do
    lines[i] := lines[i+1];
  linecount := Pred(linecount);
end;

procedure InsertLine(lnr : integer; value : linestr);
var
  i : integer;
begin
  lnr := Succ(lnr);
  for i := linecount downto lnr do
    lines[i+1] := lines[i];
  linecount := Succ(linecount);
  New(lines[lnr]);
  lines[lnr]^ := value;
end;

procedure BreakLn(lnr, index : integer);
var
  len : integer;
begin
  len := Length(lines[lnr]^) - index + 1;
  InsertLine(y, Copy(lines[lnr]^, index, len));
  Delete(lines[y]^, index, len);
end;

procedure DeleteChar(lnr, index: integer);
begin
  if Length(lines[lnr]^) <> 0 then
    Delete(lines[lnr]^, index, 1);
end;

procedure InsertChar(ch : char);
begin
  Insert(ch, lines[y]^, x);
  x := Succ(x);
  RenderCurLn;
  GotoXY(x, y - offset);
end;

{
  Start of program
}
procedure JumpToNewLn(value : linestr);
begin
  InsertLine(y, value);
  x := 1;
  GoDown;
  RenderDown;
end;

procedure ReadInsert;
var
  ch : char;
begin
  PrintStatus('-- INSERT --');
  repeat
    ch := ReadKey;
    case ch of
      #8  : begin                 { Backspace }
              if x > 0 then begin
                x := Pred(x);
                DeleteChar(y, x);
                RenderCurLn;
                GotoXY(x, y);
              end;
            end;
      #13 : begin                 { Line feed }
              if EndOfLine then
                begin
                  JumpToNewLn('');
                end
              else
                begin
                  BreakLn(y, x);
                  x := 1;
                  RenderDown;
                  GoDown;
                end;
              ReadInsert;
              ch := #27;          { Exit to cmd mode }
            end;
      #27 : ch := #27;            { ESC }
      else InsertChar(ch);        { Character }
    end;
  until ch = #27;

  if x > 1 then x := Pred(x);
  RenderCursor;
  PrintStatus('');
end;

procedure NewDoc;
begin
  New(lines[1]);
  lines[1]^ := 'New file. Thank you for using this editor.';
  linecount := 1;
end;

function FileExists(filename : string) : boolean;
var
  f : file;
  exists : boolean;
begin
  Assign(f, filename);
  {$I-}
  Reset(f);
  {$I+}
  exists := IOResult = 0;
  if exists then Close(f);
  FileExists := exists;
end;

procedure LoadFile(filename : string);
var
  countstr : string [4];
  f : text;
  i : integer;
begin
  Assign(f, filename);
  if not FileExists(filename) then
    begin
      PrintStatus('Editing new file');
      NewDoc;
      Exit;
    end;

  Reset(f);
  i := 1;
  while not Eof(f) and (i < MAX_LINES) do
    begin
      New(lines[i]);
      Readln(f, lines[i]^);
      i := Succ(i);
    end;
  Close(f);
  linecount := i - 1;

  if linecount = 0 then NewDoc;

  Str(linecount, countstr);
  PrintStatus(countstr+' lines read from '''+ParamStr(1)+'''');
end;

procedure SaveFile(filename : string);
var
  f : text;
  i : integer;
begin
  Assign(f, filename);
  Rewrite(f);
  for i := 1 to linecount do Writeln(f, lines[i]^);
  Close(f);
end;

procedure ReadCommand;
var
  countstr : string [4];
begin
  GotoXY(1, T_HEIGHT);
  PrintStatus(':');
  GotoXY(2, T_HEIGHT);
  Readln(cmd);

  { Quit }
  if cmd = 'q' then
    begin
      Halt;
    end

  { Save }
  else if cmd = 'w' then
    begin
      cmd := '';
      SaveFile(ParamStr(1));
      Str(linecount, countstr);
      PrintStatus(countstr+' lines saved to '''+ParamStr(1)+'''');
    end

  { Save and quit }
  else if cmd = 'wq' then
    begin
      SaveFile(ParamStr(1));
      Halt;
    end;
end;

procedure ShowHelp(prgname : string);
begin
  Writeln('Usage: ', prgname, ' filename');
end;

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
  offset := 0;
  cmd := '';

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
	       DeleteChar(y, x);
               RenderCurLn;
               AdjustEol;
               RenderCursor;
	     end;
      #68  : begin           { D }
  	       AdjustEol;
               if Length(lines[y]^) > 1 then
                 begin
                   lines[y]^ := Copy(lines[y]^, 1, x - 1);
                   RenderCurLn;
                   AdjustEol;
                   RenderCursor;
		 end;
               end;
      #105 : begin           { i }
               AdjustEol;
               ReadInsert;
               ch := #0;
             end;
      #73 : begin            { I }
               GoFarLeft;
               ReadInsert;
               ch := #0;
             end;
      #97  : begin           { a }
               AdjustEol;
               x := Succ(x);
               ReadInsert;
               ch := #0;
             end;
      #65  : begin           { A }
               GoFarRight;
               x := Succ(x);
               ReadInsert;
               ch := #0;
             end;
      #74  : begin           { J }
               if y < linecount then
                 begin
                   Insert(lines[y+1]^, lines[y]^, Length(lines[y]^) + 1);
                   DeleteLn(y+1);
                   RenderLn(y+1);
                   RenderDown;
                 end;
             end;
      #71  : begin           { G }
               GoToBottom;
             end;
      #0   : begin           { NULL }
               ch := ReadKey;
               case ch of
                 #75 : GoLeft;
                 #77 : GoRight;
               end;
             end;
      #58  : ReadCommand;
    end;
  until ch = #127;
end.
