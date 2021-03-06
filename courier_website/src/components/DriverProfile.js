import React, {useState, useEffect} from 'react';
import Card from 'react-bootstrap/Card';
import Spinner from 'react-bootstrap/Spinner';
import Button from 'react-bootstrap/Button';
import Alert from 'react-bootstrap/Alert';

import CenterPoint from './CenterPoint';
import DeleteDriver from './DeleteDriver';
import DriverRoutes from './DriverRoutes';

import './style/style.css';


function DriverProfile(props){
    const [DriverName, setName] = useState("");
    const [DriverSurname, setSurname] = useState("");
    const [Loading, setL] = useState(true);
    const [EditCenter, setEC] = useState(false);
    const [InvalidId, setIID] = useState(false);
    const [ShowDeleteDriver, setSDD] = useState(false);
    const [ShowDeleteRoutes, setSDR] = useState(false);

    useEffect(()=>{
        let Token = "Bearer "+ process.env.REACT_APP_BEARER_TOKEN;
        fetch(process.env.REACT_APP_API_SERVER+"/api/location/driver?id="+props.DriverID,{
            method : "GET",
            headers:{
                'authorization': Token,
                'Content-Type' : 'application/json',     
            }
        })
        .then(result=>{
            if(result.status===200){
                result.json()
                .then(response=>{
                    setName(response.drivers[0].name);
                    setSurname(response.drivers[0].surname);
                });
            }
            else{
                setIID(true);
            }
        })
        .then(()=>{
            setL(false);
        });
    },[]);

    function handleChange(event){
        if(event.target.name==="ChangeCP"){
            setEC(!EditCenter);
        }
        else if(event.target.name==="ShowDD"){
            setSDD(!ShowDeleteDriver);
        }
        else if(event.target.name==="ShowDR"){
            setSDR(!ShowDeleteRoutes);
        }  
    }


    return(
        <Card className="InnerCard">
            {Loading ?
                <Card.Body> 
                    <p>Loading</p>
                    <Spinner animation="border" role="status">
                        <span className="sr-only">Loading...</span>
                    </Spinner>
                </Card.Body>
            :   
            <div>
                {InvalidId ?
                    <Card.Body> 
                        <Alert variant="danger">The User you tried to load does not exist</Alert>
                    </Card.Body>
                    : 
                    <div>
                        <Card.Header>{DriverName + " " + DriverSurname + " ID: "+props.DriverID}</Card.Header>
                        <Card.Body>
                            <Button name="ChangeCP" onClick={handleChange}>Edit Center Point</Button>
                            {EditCenter ? <div><br /><CenterPoint DriverID={props.DriverID}/></div>: null}
                            <hr className="BorderLine"/>
                            <Button name="ShowDD" onClick={handleChange}>Delete Driver</Button>
                            {ShowDeleteDriver ? <div><br/><DeleteDriver DriverID={props.DriverID}/></div>:null}
                            <hr className="BorderLine"/>
                            <Button name="ShowDR" onClick={handleChange}>Delete Driver Routes</Button>
                            {ShowDeleteRoutes ? <div><br /><DriverRoutes DriverID={props.DriverID}/></div>:null}
                        </Card.Body>
                    </div>
                }
            </div>    
            }
            
        </Card>
    )
}

export default DriverProfile;