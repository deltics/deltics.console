
{$define CONSOLE}

{$i deltics.inc}

  program test;


uses
  Deltics.Smoketest,
  Deltics.Console in '..\src\Deltics.Console.pas';

begin
  Console.Write(RED, 'This should be RED'); Console.WriteLn;
  Console.Write(GREEN, 'This should be GREEN'); Console.WriteLn;
  Console.Write(BLUE, 'This should be BLUE'); Console.WriteLn;
  Console.PushAttr(Console.SetColor(BLUE, YELLOW));
  Console.WriteLn('This should be inverted');
  Console.PopAttr;
  Console.WriteLn('This should be back to normal');
  Console.WriteLn('This should be @red(RED), @green(GREEN), and @blue(BLUE)!');

  Console.ErrorLn('This line should also be %s', ['RED']);
end.
