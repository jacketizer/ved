program Ved (Input, Output);
uses
  Crt;

const
  MAX_LINES = 512;
  DEFAULT_WIDTH = 80;
  DEFAULT_HEIGHT = 24;

type
  filename = string [80];
  linestr = string [128];
  lineptr = ^linestr;

var
  termWidth, termHeight : integer;
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
    if startln <= linecount then
      begin
        Writeln(lines[startln]^);
        startln := Succ(startln);
      end;
    screenln := Succ(screenln);
  until (screenln > termHeight - 1);
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
  GotoXY(1, termHeight);
  TextBackground(White);
  TextColor(Black);
  ClrEol;

  if Length(cmd) <> 0 then
    begin
      Write(cmd);
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
      percent := Trunc(((offset + termHeight) / linecount) * 100);
      Str(percent, percentstr);
      percentstr := percentstr + '%';
    end;

  GotoXY(termWidth - Length(percentstr) - 1, termHeight);
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

procedure PrintStatus(msg : linestr);
begin
  status := msg;
  RenderStatus;
  RenderCursor;
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
      if (y - offset) > termHeight - 1 then
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
  if linecount > termHeight - 1 then
    begin
      offset := linecount - termHeight + 1;
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
  if lnr <> linecount then
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

procedure ConcatLn(lnr : integer);
begin
  if lnr < linecount then
    begin
      Insert(lines[Succ(lnr)]^, lines[lnr]^, Length(lines[lnr]^) + 1);
      DeleteLn(Succ(lnr));
    end;
end;

procedure CropLn(lnr, index : integer);
begin
  lines[y]^[0] := Chr(Pred(index));
end;

procedure DeleteChar(lnr, index: integer);
begin
  if Length(lines[lnr]^) <> 0 then
    Delete(lines[lnr]^, index, 1);
end;

procedure InsertChr(lnr, index : integer; ch : char);
begin
  Insert(ch, lines[lnr]^, index);
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
                GotoXY(x, y - offset);
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
      #27 : begin end;
      else  begin                 { Character }
              InsertChr(y, x, ch);
              RenderCurLn;
              x := Succ(x);
              GotoXY(x, y - offset);
            end;
    end;
  until ch = #27;

  if x > 1 then x := Pred(x);
  PrintStatus('');
end;

procedure NewDoc;
begin
  New(lines[1]);
  lines[1]^ := 'New file. Thank you for using this editor.';
  linecount := 1;
end;

function FileExists(name : filename) : boolean;
var
  f : file;
  exists : boolean;
begin
  Assign(f, name);
  {$I-}
  Reset(f);
  {$I+}
  exists := IOResult = 0;
  if exists then Close(f);
  FileExists := exists;
end;

procedure LoadFile(name : filename);
var
  f : text;
  i : integer;
  countstr : string [4];
begin
  Assign(f, name);
  if not FileExists(name) then
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
  PrintStatus(countstr + ' lines read from ''' + name + '''');
end;

procedure SaveFile(name : filename);
var
  f : text;
  i : integer;
  countstr : string [4];
begin
  Assign(f, name);
  Rewrite(f);
  for i := 1 to linecount do Writeln(f, lines[i]^);
  Close(f);

  Str(linecount, countstr);
  PrintStatus(countstr + ' lines saved to ''' + name + '''');
end;

procedure ReadCommand;
var
  ch : char;
begin
  cmd := ':';
  status := '';
  RenderStatus;
  GotoXY(2, termHeight);

  repeat
    ch := ReadKey;
    if (ch <> #13) and (ch <> #27) then
      Insert(ch, cmd, Length(cmd) + 1);
    RenderStatus;
  until (ch = #27) or (ch = #13);

  if (ch = #27) or (cmd = ':') then
    begin
      cmd := '';
      RenderStatus;
      Exit;
    end;

  { Quit }
  if cmd = ':q' then
    begin
      Halt;
    end

  { Save }
  else if cmd = ':w' then
    begin
      cmd := '';
      SaveFile(ParamStr(1));
    end

  { Save and quit }
  else if cmd = ':wq' then
    begin
      SaveFile(ParamStr(1));
      Halt;
    end
  else
    begin
      cmd := '';
      PrintStatus('Unknown command');
    end;
end;

procedure ShowHelp(prgname : filename);
begin
  Writeln('Usage: ', prgname, ' filename [terminal_width terminal_height]');
end;

var
  ch : char;
  rv : integer;
begin
  if (ParamCount <> 1) and (ParamCount <> 3) then
    begin
      ShowHelp(ParamStr(0));
      Halt;
    end;

  x := 1;
  y := 1;
  offset := 0;
  cmd := '';

  if ParamCount = 1 then
    begin
      termWidth := DEFAULT_WIDTH;
      termHeight := DEFAULT_HEIGHT;
    end
  else
    begin
      Val(ParamStr(2), termWidth, rv);
      Val(ParamStr(3), termHeight, rv);
    end;

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
                   CropLn(y, x);
                   RenderCurLn;
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
               ConcatLn(y);
               RenderDown;
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
