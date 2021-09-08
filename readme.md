> # 3tier 실습

> ## 구현요소  
- Create        : 생성
- Attachment    : 연결
- Conntect      : 확인

> ## 구현 과정
1. _Edit_ main.tf << workspace(aws_3tier)
2. _Create_ Cidr Block : map(list)
3. _Create_ VPC
4. _Create_ Subnet : Public 1~2, Private 3~4
5. _Create_ Internet Gateway
6. _Create_ NAT Gateway: Public Subnet 2
7. _Attachment_ Subnet(Public 1) - Internet Gateway
8. _Attachment_ Subnet(public 2) - NAT Gateway
9. _Create_ Bastion Instance(EC2):  - Public Subnet 1
10. _Create_ Elastic IP for Bastion(EC2)
11. _Create_ Security Group for Bastion(SSH)
12. _Attachment_ Bastion - Security Group for Bastion
13. _Create_ Route Table(For Internet Gateway): Public Subnet 1 - AWS Internet Gateway - Internet
14. _Attachment_ Route Table (For Internet Gateway) - Public Subnet 1
15. _Create_ Launch Template for Auto Scale Group(Front-End): _Attachment_ user_data
16. _Create_ Auto Scale Group(Front-End): Launch Template(Front-End)
17. _Create_ Load Balancer for Front-End : Application LB, : Public Subnet 1 / Public Subnet 2
18. _Create_ Load Balancer(Front-End) Listener
19. _Attachment_ Load Balancer(Front-End) - Listener
20. _Create_ Load Balancer Target Group(Front-End)
21. _Attachment_ Auto Sacle Group(Front-End) - Load Balancer Target Group
22. _Create_ Elastic IP for NAT Gateway
23. _Create_ Security Froup for HTTP
24. _Create_ Route Table(For NAT Gateway): Public Subnet 2 - AWS NAT Gateway - Internet
25. _Attachment_ Route Table (For NAT Gateway) - Private Subnet 2
26. _Create_ Launch Template for Auto Scale Group(Back-End): _Attachment_ user_data
27. _Create_ Auto Scale Group(Back-End): Launch Template(Back-End)
28. _Create_ Load Balancer for Back-End: Application LB, : Private Subnet 3 / Private Subnet 2
29. _Create_ Load Balancer Target Group(Back-End)
30. _Attachment_ Auto Sacle Group(Back-End) - Load Balancer Target Group
31. _Create_ Bastion, Front-End, Back-End Key Pair on Local Environment
32. _Attachment_ Lunch Template - Key Pair
33. _Connect_ Front-End Load Balancer DNS_NAME using HTTP
34. _Connect_ Bastion Public IP using SSH
35. _Connect_ Front-End, Back-End Instance from Bastion(SSH)

Done.

-----

> ## + 참고사항
현재 실습 단계에서는 구축 시간상 WEB 서버 및 WAS 서버 내부를 커스텀 하지 않았습니다.  
output은 SSH 테스트를 위한 Bastion IP와 HTTP 테스트를 위한 Front-End Load Balancer IP(DNS_NAME)만 제공합니다.

-----

> ## + 추가사항

Bastion에 Front-End, Back-End를 저장하는 방법은 Lunch Template user_data 스크립트에 S3에 저장한 private key를 가지고 오는 코드를 작성하면됩니다.  
(현재 코드에 별도로 추가하지는 않았습니다.)

-----

> ## + RSA Key 참고

각 인스턴스의 public, private 키는 /KP폴더 내에 있습니다.

생성 에시
```
➜  KP git:(main) ✗ ssh-keygen 
Generating public/private rsa key pair.
Enter file in which to save the key (/Users/-----/.ssh/id_rsa): ./bastion_key 
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in ./bastion_key.
Your public key has been saved in ./bastion_key.pub.
The key fingerprint is:
SHA256:{Key}
The key's randomart image is:
+---[RSA 3072]----+
|o++o+=O==.       |
|.*.  +=*+        |
|.*.{mosaic}     |
|+.= +. .         |
|o.. ..  S        |
|o...{mosaic}.    |
|...  ..  . o o   |
|      o...o . .  |
|     ..o++       |
+----[SHA256]-----+
➜  KP git:(main) ✗ ls
bastion_key     bastion_key.pub
➜  KP git:(main) ✗ 
```

