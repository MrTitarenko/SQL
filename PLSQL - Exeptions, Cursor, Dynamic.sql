@ d:\hr_create.sql
@ d:\hr_popul.sql
SET LINESIZE 120
SET PAGESIZE 50

--	1.1. Создать запрос типа INSERT ALL по автоматической регистрации в БД 10000 сотрудников.
INSERT ALL
INTO employees (employee_id, first_name, last_name, email, hire_date, job_id)
    VALUES (300+rn, 'Vitalii' || rn, 'Titarenko' || rn, 'VT' || rn, 
            TO_DATE('01-01-2000', 'dd-mm-yyyy') + rn, 'FI_MGR')
SELECT rownum as rn FROM dual
CONNECT BY level <= 10000;
--	10,000 rows inserted.

--	1.2. Создать анонимный PL/SQL-блок, автоматически регистрирующий в БД 10000 сотрудников, учитывая условия из задания 1.1.
ROLLBACK;
BEGIN
	FOR i IN 1..10000 LOOP
		INSERT INTO employees 
              (employee_id, first_name, last_name, email, hire_date, job_id)
		VALUES(300 + i, 
				'Vitalii ' || TO_CHAR(i), 
				'Titarenko ' || TO_CHAR(i),
				'VT ' || TO_CHAR(i),
				to_date('01/01/2000','DD/MM/YYYY') + i,
				'FI_MGR');
	END LOOP;	
END;
/


--	Задание 2. Обработка исключений
DECLARE
    l_name employees.last_name%TYPE;
    sal employees.salary%TYPE;
    negative_salary exception;
BEGIN
	FOR i IN 1..10000 LOOP
    sal:=-10*i;
    IF sal < 0 THEN RAISE negative_salary;
    END IF;
		INSERT INTO employees 
        (employee_id, first_name, last_name, email, hire_date, job_id, salary)
		VALUES(300 + i, 
				'Vitalii ' || TO_CHAR(i), 
				'Titarenko ' || TO_CHAR(i),
				'VT ' || TO_CHAR(i),
				to_date('01/01/2000','DD/MM/YYYY') + i,
				'FI_MGR',
				sal);
    END LOOP;	
  EXCEPTION
    WHEN DUP_VAL_ON_INDEX  THEN
      RAISE_APPLICATION_ERROR(-20555,
        'E-mail ' || l_name || ' already exists!');
    WHEN negative_salary THEN  
      RAISE_APPLICATION_ERROR(-20560,
        'Salary = ' || sal || ' is incorrect salary!');
END;
/


/*
Задание 3 Работа с курсорами
Описать операции транзакции в виде PL/SQL-кода:
1) получить список идентификаторов подразделений, в которых есть сотрудники;
2) получить список сотрудников 2-го по списку подразделения;
3) перевести сотрудников в 3-е по списку подразделение
4) сохранить данные о сотрудниках в таблице job_history
*/
DECLARE 
 CURSOR dep_c IS 
   SELECT DISTINCT DEPARTMENT_ID AS d_id FROM EMPLOYEES
     WHERE DEPARTMENT_ID IS NOT NULL;
 dep_id dep_c%ROWTYPE;
 dep_up_id dep_c%ROWTYPE;
 CURSOR emp_c IS 
   SELECT * FROM EMPLOYEES
     WHERE DEPARTMENT_ID = dep_id.d_id;
 empl emp_c%ROWTYPE;    
BEGIN
 OPEN dep_c;
 FETCH dep_c INTO dep_id;
 FETCH dep_c INTO dep_id;
 OPEN emp_c;
 FETCH emp_c INTO empl;
 FETCH dep_c INTO dep_up_id;
 WHILE emp_c%FOUND LOOP
   DBMS_OUTPUT.PUT_LINE(empl.employee_id || ' ' || empl.first_name || ' ' || empl.last_name || ' ' || empl.department_id);
   UPDATE EMPLOYEES SET DEPARTMENT_ID = dep_up_id.d_id
     WHERE EMPLOYEE_ID = empl.EMPLOYEE_ID;
   INSERT INTO JOB_HISTORY(EMPLOYEE_ID, START_DATE, END_DATE, JOB_ID, DEPARTMENT_ID)
     VALUES(empl.employee_id, empl.HIRE_DATE, SYSDATE, empl.JOB_ID, dep_id.d_id);
   FETCH emp_c INTO empl;
 END LOOP;
END;


--	Задание 4 Автоматическая инициализация генераторов уникальных значений
DECLARE
  max_emp_id NUMBER(20);
  max_dep_id NUMBER(20);
  dep_exists NUMBER(2);
  empl_exists NUMBER(2);

BEGIN
  SELECT max(department_id) 
    INTO max_dep_id
    FROM departments;
  SELECT max(employee_id) 
    INTO max_emp_id
    FROM employees;

  SELECT 1 INTO dep_exists
    FROM sys.user_sequences
    WHERE sequence_name = upper('department_id');  
  IF SQL%FOUND then
    EXECUTE IMMEDIATE 'drop sequence department_id';
  END IF;

  SELECT 1 INTO empl_exists
    FROM sys.user_sequences 
    WHERE sequence_name = upper('employee_id');
  IF SQL%FOUND then
    EXECUTE IMMEDIATE 'drop sequence employee_id';
  END IF;

  EXECUTE IMMEDIATE
  'CREATE SEQUENCE employee_id
    INCREMENT BY 1
    START WITH ' || (max_emp_id+1);
  EXECUTE IMMEDIATE
  'CREATE SEQUENCE department_id
    INCREMENT BY 10
    START WITH ' || (max_dep_id+1);
END;

-- 4.2 В решение 1-го задания изменить PL/SQL-код так, чтобы не было необходимости проверять наличие генераторов в БД через создание заглушки
DECLARE
  max_emp_id NUMBER(20);
  max_dep_id NUMBER(20);

BEGIN
  SELECT max(department_id) 
    INTO max_dep_id
    FROM departments;
  SELECT max(employee_id) 
    INTO max_emp_id
    FROM employees;
    
  BEGIN
		EXECUTE IMMEDIATE 'DROP SEQUENCE department_id';
    EXCEPTION	WHEN OTHERS THEN
			-- игнорирование ошибки
			NULL;
  END;
  BEGIN
		EXECUTE IMMEDIATE 'DROP SEQUENCE employee_id';
    EXCEPTION	WHEN OTHERS THEN
			-- игнорирование ошибки
			NULL;
  END;
  
  EXECUTE IMMEDIATE
  'CREATE SEQUENCE employee_id
    INCREMENT BY 1
    START WITH ' || (max_emp_id+1);
  EXECUTE IMMEDIATE
  'CREATE SEQUENCE department_id
    INCREMENT BY 10
    START WITH ' || (max_dep_id+1);
END;


--	Задание 5 Динамические запросы
DECLARE
	CURSOR curss IS
    SELECT e.email, j.job_title
		FROM employees e
      JOIN jobs j
      ON e.job_id = j.job_id
          WHERE e.last_name LIKE 'C%' 
             OR e.last_name LIKE 'D%';
  login VARCHAR2(50);
BEGIN
	FOR rec IN curss LOOP
    login:= rec.email;
      EXECUTE IMMEDIATE 'CREATE USER ' || login || ' IDENTIFIED BY q123';
      EXECUTE IMMEDIATE 'GRANT CONNECT TO ' || login;
    IF rec.job_title LIKE '%Manager' THEN
      EXECUTE IMMEDIATE 'GRANT RESOURCE TO ' || login;
    END IF;
  END LOOP;
END;
/