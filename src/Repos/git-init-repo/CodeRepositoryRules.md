# **Code Repository**



## Overview



✔️ **DO** **one** **repository** per application (application cataloged in ARD), for application self-contain, non-shareable code. * 

✔️ **DO** PascalCasing for naming. Not applicable for acronyms

❌ **DO NOT** **exceed** **the** maximum path 256 characters

❌ **DO NOT** **use s**pecial characters such as ~ ! @ # $ % ^ & * ( ) ` ; < > ? , [ ] { } ' " and |

✔️ **DO** When using a sequential numbering system, using leading zeros for clarity and to make sure files sort in sequential order. For example, use "001, 002, ...010, 011 ... 100, 101, etc." instead of "1, 2, ...10, 11 ... 100, 101, etc.“

❌ **DO NOT** include date and time stamps in files/folder names

❌ **DO NOT** use V1.x to refer a version of file, Git is responsible to versioning files in a repo

❌ **DO NOT** use words (Trash, Old, Lixo, Remove) in file\folder name

❌ **DO NOT** use spaces. Some software will not recognize file names with spaces, and file names with spaces must be enclosed in quotes when using the command line.️ No separation, e.g. fileName.xxx



## General Structure




>  **Attention: This structure level is created automatically based on template code repository.** 
>
>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;**To achieve a consistent folder structure, <u>Teams don’t have permission to change it</u>.** 



├─ **config**	#Configuration file

├─ **database**	#Data Base script

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **ddl**	#Data Definition Language: commands that can be used to define the database schema (create, drop, alter, truncate, comment, rename) 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **dql**	#Data Query Language: is to get some schema relation based on the query passed to it (select)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **dml**	#Data Manipulation Language: commands that deals with the manipulation of data (insert, update, delete)

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **dcl**	#Data Control Language: includes commands such as GRANT and REVOKE which mainly deals with the rights, permissions and other controls of the database system

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└─ **tcl**	#Transaction Control Language: commands deals with the transaction within the database (commits, rollbacks, save points, set transaction) 

├─ **doc**	#Documentation files

├─ **src**	#Source files (notebooks source code exe databricks)

├─ **test**	#Automated and manual tests: non-functional tests, functional 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **benchmark**	#Non-Functional Tests: load and stress tests, performance, security

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **integration**	#End-to-end, integration tests

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└─ **unit**	#Unit tests 

├─ **tool**	#Tools and utilities 

├─ **lib**	#3rd party libraries 



#### Data Science Extension



├─ **sampleData**	#sample data for training, assessment in the different datasets treatment

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **raw**	#raw data 

​&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **conformed**	#conformed data 

​&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;├─ **dataScience**	#data science data 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;└─ **reporting**	#reporting data 

├─ **notebooks**	#Notebooks for **research** scope: standard the **data science research** with a mix of code and reporting / visualization

├─ **models**	#Models: serialized models, predictions, summaries



## General Rules



1. Force push: only Admin users must have access
2. Bypass policies when completing pull requests: only Admin users must have access
3. Bypass policies when pushing: only Admin users must have access
4. Contribute: all users must contribute
5. Create branch: all users can create branch
6. Edit policies: only Admin uses must have access
7. Manage permissions: only Admin uses must have access
8. Remove others' locks: only Admin uses must have access
9. Require a minimum number of reviewers = 2
10. Reset code reviewer votes when there are new changes = true
11. Check for linked work items = true
12. Check for comment resolution = true
13. Limit merge types = No Rebase Option
14. Reviewers = Required (create Security Group in AD Repository "Code Reviewers") add this to the REVIEWERS