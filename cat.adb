with Ada.Containers;      use Ada.Containers;
with Const_H;             use Const_H;
with Contents_Table_Type; use Contents_Table_Type;
with Interfaces.C;        use Interfaces.C;
with Iostr;               use Iostr;
with Lemmas;              use Lemmas;
with Stdio;               use Stdio;
with Ada.Command_Line;
with Errors;
with Full_Write;
with Perror;
with Safe_Read;

use Contents_Table_Type.Formal_Maps;
use Contents_Table_Type. Formal_Maps.Formal_Model;
use Iostr.Ghost_Package;

procedure Cat with
  SPARK_Mode => On,
  Pre        =>
    (Contains (Contents, Stdin)
       and then Contains (Contents, Stdout)
       and then Contains (Contents, Stderr)
       and then Length (Element (Contents, Stdin)) = 0
       and then Length (Element (Contents, Stdout)) = 0
       and then Length (Element (Contents, Stderr)) = 0)
is
   X : int;
   Err : int;

   function Err_Message (Str : String) return String is
     (case Str'Length is
      when 0 .. Natural'Last - 5 => "cat: " & Str,
      when others                =>
        "cat: " & Str (Str'First .. Natural'Last - 6 + Str'First));

   procedure Copy_To_Stdout (Input : int; Err : out int) with
     Global => (Proof_In => (FD_Table),
                In_Out   => (Contents, Errors.Error_State)),
     Pre    =>
       Contains (Contents, Stdout)
         and then Contains (Contents, Input)
         and then Input >= 0
         and then Input /= Stdout
         and then Length (Element (Contents, Input)) = 0,
     Post =>
       M.Same_Keys (Model (Contents'Old), Model (Contents))
         and then
       M.Elements_Equal_Except (Model (Contents),
                                Model (Contents'Old),
                                Input,
                                Stdout)
         and then
      (if Err = 0
       then
         Element (Contents, Stdout)
         = Element (Contents'Old, Stdout)
         & Element (Contents, Input));

   procedure Copy_To_Stdout (Input : int; Err : out int) is
      Contents_Pcd_Entry : constant Map (OPEN_MAX - 1,
                                         Default_Modulus (OPEN_MAX - 1)) :=
        Contents with Ghost;
      Contents_Old : Map (OPEN_MAX - 1, Default_Modulus (OPEN_MAX - 1))  :=
        Contents with Ghost;
      Old_Stdout, Old_Input : Unbounded_String with Ghost;
      Buf : Init_String (1 .. 1024);
      Has_Read : ssize_t;
   begin
      pragma Assert (M.Elements_Equal_Except
                      (Model (Contents),
                       Model (Contents_Pcd_Entry),
                       Input,
                       Stdout));
      pragma Assert (Element (Contents_Old, Stdout)
                     = Element (Contents_Pcd_Entry, Stdout)
                     & Element (Contents_Old, Input));
      loop
         Contents_Old := Contents;
            pragma Assert (Element (Contents_Old, Stdout)
                           = Element (Contents_Pcd_Entry, Stdout)
                           & Element (Contents_Old, Input));

         Safe_Read (Input, Buf, Has_Read);
         pragma Assert (Element (Contents, Stdout)
                        = Element (Contents_Old, Stdout));
         pragma Assert (M.Elements_Equal_Except
                         (Model (Contents),
                          Model (Contents_Pcd_Entry),
                          Input,
                          Stdout));
         pragma Assert (M.Same_Keys (Model (Contents_Pcd_Entry),
                                     Model (Contents)));
         pragma Assert (Element (Contents, Input)
                        = Append (Element (Contents_Old, Input),
                                  Buf,
                                  Has_Read));
         if Has_Read = 0 then
            Equal_String (Element (Contents, Stdout),
                          Element (Contents_Old, Stdout),
                          Element (Contents_Pcd_Entry, Stdout),
                          Element (Contents_Old, Input));
            Equal_And_Append (Element (Contents, Stdout),
                              Element (Contents_Pcd_Entry, Stdout),
                              Element (Contents_Old, Input),
                              Element (Contents, Input));
            exit;
         elsif Has_Read = -1 then
            Err := -1;
            return;
         end if;

         Old_Stdout := Element (Contents, Stdout);
         pragma Assert (size_t (Has_Read) <= Buf'Length);
         Full_Write
           (Stdout,
            Buf,
            size_t (Has_Read),
            Err);
         pragma Assert (M.Elements_Equal_Except
                        (Model (Contents),
                           Model (Contents_Pcd_Entry),
                           Input,
                           Stdout));
         if Err = -1 then
            return;
         end if;
         Equal_And_Append (Element (Contents, Stdout),
                           Old_Stdout,
                           Element (Contents_Old, Stdout),
                           Buf,
                           Has_Read);
         Prove_Equality (Contents,
                         Contents_Old,
                         Contents_Pcd_Entry,
                         Buf,
                         Has_Read,
                         Input,
                         Stdout);

         pragma Loop_Invariant (M.Same_Keys
                                  (Model (Contents_Pcd_Entry),
                                   Model (Contents)));
         pragma Loop_Invariant (M.Elements_Equal_Except
                                  (Model (Contents),
                                   Model (Contents_Pcd_Entry),
                                   Stdout,
                                   Input));
         pragma Loop_Invariant (Element (Contents, Stdout)
                                = Element (Contents_Pcd_Entry, Stdout)
                                & Element (Contents, Input));
      end loop;

      Err := 0;
   end Copy_To_Stdout;

begin
   if Ada.Command_Line.Argument_Count = 0 then
      Copy_To_Stdout (Stdin, Err);
      if Err = -1 then
         Perror ("cat: ");
      end if;
   else
      for I in 1 .. Ada.Command_Line.Argument_Count loop
         if Ada.Command_Line.Argument (I) = "-" then
            X := Stdin;
         else
            Open (To_C (Ada.Command_Line.Argument (I)), ADA_O_RDONLY, X);
            if X = -1 then
               Perror (Err_Message (Ada.Command_Line.Argument (I)));
            end if;
         end if;

         if X /= -1 then
            Copy_To_Stdout (X, Err);

            if Err = -1 then
               Perror (Err_Message (Ada.Command_Line.Argument (I)));
            end if;

            if X /= Stdin then
               Close (X, Err);

               if Err = -1 then
                  Perror (Err_Message (Ada.Command_Line.Argument (I)));
               end if;
            else
               Reset (Stdin);
            end if;
         end if;

         pragma Assert (X /= Stdout);
         pragma Assert (Contains (Contents, Stdout));
         pragma Loop_Invariant (Contains (Contents, Stdout));
         pragma Loop_Invariant (Contains (Contents, Stdin));
         pragma Loop_Invariant (Length (Element (Contents, Stdin)) = 0);
      end loop;
   end if;
end Cat;
