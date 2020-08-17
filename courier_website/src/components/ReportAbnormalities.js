import React, {useState, useEffect} from 'react';
import Card from 'react-bootstrap/Card';
import Spinner from 'react-bootstrap/Spinner';
import Alert from 'react-bootstrap/Alert';
import Button from 'react-bootstrap/Button';
import Row from 'react-bootstrap/Row';
import Col from 'react-bootstrap/Col';

import Abnormality from './Abnormality';

function ReportAbnormalities(props){

    const [AbnormalityArr, setAA] = useState([]);
    const [Loading, setL] = useState(true);
    const [ServerError, setSE] = useState(false);
    const [Failed, setF] = useState(false);
    const [NumberAbbnormalities, setNA] = useState(0);
    const [SeeAb, setSA] = useState(false);

    useEffect(()=>{
        let Token = "Bearer "+ process.env.REACT_APP_BEARER_TOKEN;
        fetch("https://drivertracker-api.herokuapp.com/api/abnormalities/"+props.DriverID,{
            method : "GET",
            headers:{
                'authorization': Token,
                'Content-Type' : 'application/json',     
            }
        })
        .then(respone=>{
            if(respone.status===200){
                setL(false);
                respone.json()
                .then(result=>{
                    let AbArr = {};
                    let length = 0;
                    let Counter = 0;
                    let AbObj = {};
                    if(result.abnormalities.code_100.driver_abnormalities.length!=0){
                        length = length + result.abnormalities.code_100.driver_abnormalities.length;
                        result.abnormalities.code_100.driver_abnormalities.map((CurrEle, index)=>{
                            AbArr[Counter] = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Standing still for too long.'}
                            Counter++;
                            AbObj = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Standing still for too long.'}; 
                            setAA(prevState=>{return([...prevState, AbObj])});
                        })
                    }
                    if(result.abnormalities.code_101.driver_abnormalities.length!=0){
                        length = length + result.abnormalities.code_101.driver_abnormalities.length;
                        result.abnormalities.code_101.driver_abnormalities.map((CurrEle, index)=>{
                            AbArr[Counter] = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver came to a sudden stop.'}
                            AbObj = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver came to a sudden stop.'};
                            Counter++;
                            setAA(prevState=>{return([...prevState, AbObj])});
                        })
                    }
                    if(result.abnormalities.code_102.driver_abnormalities.length!=0){
                        length = length + result.abnormalities.code_102.driver_abnormalities.length;
                        result.abnormalities.code_102.driver_abnormalities.map((CurrEle, index)=>{
                            AbArr[Counter] = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver exceeded the speed limit.'}
                            AbObj = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver exceeded the speed limit.'};
                            Counter++;
                            setAA(prevState=>{return([...prevState, AbObj])});
                        })
                    }
                    if(result.abnormalities.code_103.driver_abnormalities.length!=0){
                        length = length + result.abnormalities.code_103.driver_abnormalities.length;
                        result.abnormalities.code_103.driver_abnormalities.map((CurrEle, index)=>{
                            AbArr[Counter] = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver took a diffrent route than what prescribed.'}
                            Counter++;
                            AbObj = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver took a diffrent route than what prescribed.'};
                            setAA(prevState=>{return([...prevState, AbObj])});
                        })
                    }
                    if(result.abnormalities.code_104.driver_abnormalities.length!=0){
                        length = length + result.abnormalities.code_104.driver_abnormalities.length;
                        result.abnormalities.code_104.driver_abnormalities.map((CurrEle, index)=>{
                            AbArr[Counter] = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver was driving with the company car when no deliveries were scheduled.'}
                            AbObj = AbArr[Counter] = {'Reason' : CurrEle.driver_description, 'timestamp':CurrEle.timestamp, 'ID':Counter, 'Desc':'Driver was driving with the company car when no deliveries were scheduled.'};
                            Counter++;
                            setAA(prevState=>{return([...prevState, AbObj])});
                        })
                    }
                    setNA(length);
                });
            }
            else if(respone.status===500){
                setL(false);
                setSE(true);
            }
            else{
                setL(false);
                setF(true);
            }
        })
    },[]);

    function SeeAbnor(){
        setSA(!SeeAb);
    }

    return (
        <div>
            {Loading ? 
                <Spinner animation="border" role="status">
                    <span className="sr-only">Loading...</span>
                </Spinner>
            :
                <Card>
                    <Card.Header>Report</Card.Header>
                    <Card.Body>
                        {ServerError ? <Alert variant="warning">An Error occured on the Server.</Alert>:null}
                        {Failed ? <Alert variant="warning">Either the Driver could not be found, or he has no abnormalities to report</Alert>:null}
                        <p>The Driver has {NumberAbbnormalities} abnormalities so far.</p>
                            <Row>
                                <Col xs={4}>
                                    {AbnormalityArr.map((item, index)=>
                                        <Abnormality
                                            ID={index+1}
                                            key={index}
                                            Desc={item.Desc}
                                            Reason={item.Reason}
                                            Date={item.timestamp}
                                        />
                                    )}
                                </Col>
                            </Row>
                    </Card.Body>
                </Card>
            }
        </div>
    );
}

export default ReportAbnormalities;