Created by : Apoorva Deshpande
--------------------------------
Contact info 	: http://www.linkedin.com/in/appsdesh

Description 	: Script to track and maintain database changes.


1. db_script_runner is a Perl script to execute SQL scripts for updating the database
   -h would give you the help menu.
2. It will try to execute sql scripts from the folder specified by -f option.
3. Database name, username, password, db host could be provided as command line options.
3. All of the sql scripts should scrictly enforce following naming convention.
	sql_\d{1,10}_*.sql ( ==> sql_{number}_{text}.sql where number and text are placeholders )
4. Where the integer number would help in ensuring the script execution order.
5. For any changes in the current script one needs to create a new script with
   the next number in ascending order.
6. This scripts maintains the database state in CONFIG_SCRIPTS table, this table
   keeps track of all those sql scripts which are previously executed.
7. db_script_runner would execute only those sql scripts which are yet to be executed.
8. db_script_runner follows the following algorithm
	a. Check if CONFIG_SRIPTS table exists.
		i. If NO then create it.
	b. Check which was the last sql script executed.
	c. Check in the folder for newer sql script.
		 i.  Execute newer script ( Fail on error. Manual intervention needed. )
		ii.	 Make an entry in the CONFIG_SRIPTS table.
	d. exit
9. eg. db_script_runner is executed for the first time.
	Folder contains follwing scripts.
	sql_1_r2-1.sql
	sql_2_r2-2.sql
	sql_3_r2-3-prod.sql
	sql_4_r2-3-1.sql
	sql_5_r2-4.sql
	Then db_script_runner would create CONFIG_SCRIPT table in the specified db ( As it is running for the first time ).
	Since the CONFIG_SCRIPTS table is empty all sql scripts are considered NEW. db_script_runner would execute all scripts
	one at a time enforcing the sorted ascending order of {number}.
	
	If someone modifies one of the script or adds a new script then it should be stored as sql_6_modified/added.sql
	The next time when db_script_runner is invoked it will check the db state by looking at CONFIG_SCRIPTS table 
	and identifies sql_6_modified/added.sql as an only candidate for execution.
	