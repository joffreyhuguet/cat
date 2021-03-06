with System;

package body Stdio with
  SPARK_Mode => Off
is

   --------------------------------
   --  Bindings to system calls  --
   --------------------------------

   function C_Open (File : char_array; Flags : int) return int;
   pragma Import (C, C_Open, "open");

   function C_Read
     (Fd     : int;
      Buf    : System.Address;
      Size   : size_t;
      Offset : off_t) return ssize_t;
   pragma Import (C, C_Read, "read");

   function C_Close (Fd : int) return int;
   pragma Import (C, C_Close, "close");

   function C_Write (Fd : int; Buf : System.Address; Nbyte : size_t)
                     return ssize_t;
   pragma Import (C, C_Write, "write");

   -------------
   --  Close  --
   -------------

   procedure Close (Fd : int; Result : out int) is
   begin
      Result := C_Close (Fd);
      --  Call to C binding

      if Result = 0 then
         Delete (Contents, Fd);
      end if;
      --  Postcondition
   end Close;

   ------------
   --  Open  --
   ------------

   procedure Open (File : char_array; Flags : int; Fd : out int) is
   begin
      Fd := C_Open (File, Flags);
      --  Call to C binding

      if Fd >= 0 then
         Insert (Contents, Fd, Null_Unbounded_String);
      end if;
      --  This block makes the postcondition true. It is not verified by SPARK.
   end Open;

   ------------
   --  Read  --
   ------------

   procedure Read (Fd : int; Buf : out Init_String; Has_Read : out ssize_t) is
   begin
      Has_Read := C_Read (Fd, Buf'Address, Buf'Length, 0);
      --  Call to C binding

      if Has_Read > 0 then
         Replace (Contents,
                  Fd,
                  Append (Element (Contents, Fd), Buf, Has_Read));
      end if;
      --  Postcondition
   end Read;

   -------------
   --  Reset  --
   -------------

   procedure Reset (Fd : int) is
   begin
      if Contains (Contents, Fd) then
         Replace (Contents, Fd, Null_Unbounded_String);
         null;
      end if;
   end Reset;

   -------------
   --  Write  --
   -------------

   procedure Write
     (Fd          : int;
      Buf         : in Init_String;
      Num_Bytes   : size_t;
      Has_Written : out ssize_t) is
   begin
      Has_Written := C_Write (Fd, Buf'Address, Num_Bytes);
      --  Call to C binding

      if Has_Written > 0 then
         Replace (Contents,
                  Fd,
                  Append (Element (Contents, Fd), Buf, Has_Written));
      end if;
      --  Postcondition
   end Write;

begin
   Insert (Contents, Stdin,  Null_Unbounded_String);
   Insert (Contents, Stdout, Null_Unbounded_String);
   Insert (Contents, Stderr, Null_Unbounded_String);
   --  Inserts Stdin, Stdout, Stderr in Contents
end Stdio;
